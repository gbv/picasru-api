#!/usr/bin/perl
use v5.14.1;

use JSON;
use PICA::Data 'pica_fields';
use PICA::Path;
use Plack::Request;
use Plack::Middleware::ContentLength;
use Try::Tiny;
use HTTP::Tiny;
use XML::LibXML;
use XML::LibXML::XPathContext;
use Catmandu;
use Catmandu::Importer::SRU;

Catmandu->load('./config');

my $dbs = Catmandu->config->{importer};

sub is_pica_sru_importer {
    $_[0]->{package} eq 'SRU'
      && $_[0]->{options}{parser} eq "picaxml"
      && $_[0]->{options}{recordSchema} eq "picaxml";
}

# TODO: map to more useful (title, base...)
$dbs = {
    map { ( "$_" => $dbs->{$_} ) }
    grep { is_pica_sru_importer( $dbs->{$_} ) } %$dbs
};

sub json_response {
    my ( $result, %config ) = @_;

    my $JSON = JSON::PP->new->utf8;
    $JSON = $JSON->pretty(1)->canonical(1)
      if $config{pretty} // $result->{error} // $result->{count};

    my $code = $result->{status} // ( $result->{error} ? 500 : 200 );
    $result = [ $JSON->encode($result) ];

    my $headers = [
        'Content-Type'                => 'application/json; charset=UTF-8',
        'Access-Control-Allow-Origin' => '*',
        'Content-Length'              => Plack::Util::content_length($result),
    ];

    return [ $code, $headers, $result ];
}

sub query {
    my ( $id, $param ) = @_;

    my $query = $param->{query}
      // return { error => "missing query parameter" };
    my $limit = $param->{limit};
    my $path  = $param->{path};

    if ($path) {
        eval {
            $path = [ map { PICA::Path->new($_) } split /[,|\s]/, $path ];
        };
        return { error => ( $@ =~ s/ at .+//msr ), status => 403 } if $@;
    }
    else {
        $path = [];
    }

    my $count = defined $limit && $limit == 0;

    my %config = ( query => $query, total => $limit // 10 );
    $config{parser} = 'meta' if $count;

    my ( $records, $meta, $error );
    eval {
        my $importer = Catmandu->importer( $id, \%config );
        local $SIG{__WARN__} = sub { $error = shift };
        if ($count) {
            my $result = $importer->next;
            $meta = {
                url   => $result->{requestUrl},
                count => $result->{numberOfRecords},
            };
        }
        else {
            $records =
              $importer->map( sub { pica_fields( $_[0], @$path ) } )->to_array;
        }
    };
    if ( $records || $meta ) {
        return {
            query => $query,
            records => $records || [],
            %{ $meta || {} },
        };
    }
    else {
        $error //= $@ || "query failed";
        return { error => ( $error =~ s/ at .+//msr ) };
    }
}

sub database {
    my $db = $dbs->{ $_[0] };

    my $url = $db->{options}{base};
    my $res = HTTP::Tiny->new->get($url);
    if ( $res->{success} ) {

        # TODO: handle exceptions, maybe move to Catmandu::SRU?
        my $doc = XML::LibXML->new->parse_string( $res->{content} );
        my $xc  = XML::LibXML::XPathContext->new( $doc->documentElement );
        $xc->registerNs( "e", "http://explain.z3950.org/dtd/2.0/" );

        for ( $xc->findnodes("//e:index") ) {
            my $id =
              $xc->findvalue( "concat(e:map/e:name/\@set,'.',e:map/e:name)",
                $_ );
            $db->{index}{$id} = $xc->findvalue( "e:title", $_ );
        }

        return $db;
    }
    else {
        return { error => "$res->{status} $res->{reason}" };
    }
}

sub {
    my $req = Plack::Request->new(shift);
    my $id = substr $req->path, 1;

    if ( $id eq '' ) {
        return json_response( $dbs, pretty => 1 );
    }
    elsif ( $dbs->{$id} ) {
        if ( $req->parameters->keys ) {
            return json_response( query( $id, $req->parameters ) );
        }
        else {
            return json_response( database($id), pretty => 1 );
        }
    }
    else {
        return json_response( { error => "not found", status => "400" } );
    }
  }
