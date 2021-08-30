#!/usr/bin/perl
use v5.14.1;

use JSON;
use PICA::Data 'pica_fields';
use PICA::Path;
use Plack::Request;
use Plack::Middleware::ContentLength;
use Try::Tiny;
use Catmandu;
use Catmandu::Importer::SRU;

Catmandu->load('./config');

my $db = Catmandu->config->{importer};

sub is_pica_sru_importer {
    $_[0]->{package} eq 'SRU' && $_[0]->{options}{parser} eq "picaxml"
    && $_[0]->{options}{recordSchema} eq "picaxml";
}

# TODO: map to more useful (title, base...)
$db = { map { ("$_" => $db->{$_}) } grep { is_pica_sru_importer($db->{$_}) } %$db };

sub json_response {
    my ($result, %config) = @_;

    my $JSON = JSON::PP->new->utf8;
    $JSON = $JSON->pretty(1) if $config{pretty} // $result->{error};

    my $code = $result->{status} // ($result->{error} ? 500 : 200);
    $result = [$JSON->encode($result)];

    my $headers = [
        'Content-Type' => 'application/json; charset=UTF-8',
        'Access-Control-Allow-Origin' => '*',
        'Content-Length' => Plack::Util::content_length($result),
    ];
 
    return [$code, $headers, $result];
}

sub query {
    my ($id, $param) = @_;

    my $query = $param->{query} // return { error => "missing query parameter" };
    my $limit = $param->{limit};
    my $path  = $param->{path};

    if ($path) {
        eval { $path = [ map { PICA::Path->new($_) } split /[,|\s]/, $path ] };
        return { error => ($@ =~ s/ at .+//msr), status => 403 } if $@;
    } else {
        $path = [];
    }   

    my $config = { query => $query };
    $config->{total} = $limit || 10;

    #if limit=0: parser: meta

    my ($error, $records);
    eval {
        my $importer = Catmandu->importer($id, $config);
        local $SIG{__WARN__} = sub { $error = shift };
        $records = $importer->map(sub {pica_fields($_[0],@$path)})->to_array; 
    };
    if ($records) {
        return { records => $records };
    } else {
        $error //= $@ || "query failed";
        return { error => ($error =~ s/ at .+//msr) };
    }
}

sub { 
    my $req = Plack::Request->new(shift);
    my $id = substr $req->path, 1;

    if ($id eq '') {
        return json_response($db, pretty => 1);
    } elsif($db->{$id}) {
        if ($req->parameters->keys) {
            return json_response(query($id, $req->parameters));
        } else {
            return json_response($db->{$id}, pretty => 1);
        }
    } else {
        return json_response({error => "not found", status => "400"});
    }
}
