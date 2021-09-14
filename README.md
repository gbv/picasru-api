# picasru-api

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

    pm2 reload picasru-api

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

Perform an SRU searchRetrieve request and return the result in a JSON object

**Parameters:**

* `query`: mandatory CQL-query
* `limit`: optional maximum number of records to retrieve. Set to 10 by default.
* `path`: optional comma-separated list of PICA-Fields (in PICA Path syntax) to reduce PICA records

**Result object keys:**

* `error` on error
* `query` the CQL query
* `count` the number of records (if request parameter `limit=0`)
* `records` an array of PICA records in PICA JSON format (unless `limit=0`)

## Examples

See <https://pro4bib.github.io/pica/#/schnittstellen?id=sru> for a German description of querying PICA data via SRU.

Some sample CQL queries tested with K10plus:

* `pica.ppn=161165839X` get a record by its PPN
* `pica.ddc=335.83092` get records by DDC numbers
* `pica.ddc=335.83092 and (pica.jah=2014 or pica.jah=2015)` get records by DDC numbers and additional restriction on years

## LICENSE

MIT License.
