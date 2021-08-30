# picajson-sru

This repository implements a simple wrapper API to query PICA+ records in PICA from SRU endpoints, so clients don't need to know about details of SRU specification or parsing XML.

## Installation

Install files from source:

    git clone https://github.com/gbv/picasru-api.git

Install dependencies. Requires Perl >= 5.14, cpanminus and local::lib.

    eval $(perl -Mlocal::lib=local)
    cpanm --installdeps --notest .

You may first need to install system packages listed in `apt.txt`:

    sudo xargs apt-get -y install < apt.txt

Add a configuration file (see below).

Deploy with pm2 to run service on port 4006 (modify `ecosystem.config.json` to change port if needed):

    pm2 start ecosystem.config.json

To update:

    pm2 reload occurrences-api

## Configuration

The `config/` directory contains Catmandu configuration files with any number of SRU PICA Importers, e.g. add `catmandu.local.yml`:

~~~yaml
importer:
  k10plus:
    package: SRU
    options:
      base: http://sru.k10plus.de/opac-de-627
      recordSchema: picaxml
      parser: picaxml
~~~ 

## API

### GET /

List configuration of all databases.

### GET /{dbkey}

Get configuration of a selected database.

### GET /{dbkey}?params

Perform an SRU searchRetrieve request and return the result set in JSON.

**Parameters:**

* `query`: mandatory CQL-query
* `limit`: optional maximum number of records to retrieve. Set to 10 by default.
* `path`: optional comma-separated list of PICA-Fields (in PICA Path syntax) to reduce PICA records

**Result format:**

Always returns a JSON object. On error there is a key `error`, otherwise there
is a key `records` with an array of PICA records in PICA JSON format unless
`limit=0`. If `limit=0` the result contains no records but a key `count` with
the number of records.

## LICENSE

MIT License.
