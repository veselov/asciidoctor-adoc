# Asciidoctor-aDoc

**This code is a WiP, and this point is just a joke**

An AsciiDoctor converter extension that converts AsciiDoc back to AsciiDoc text.

See also:

- https://github.com/asciidoctor/asciidoctor/issues/1793

Thanks to Owen T. Heisler and his [asciidoctor-multipage](https://github.com/owenh000/asciidoctor-multipage) 
extension that I scavenged to bootstrap this workspace.

## Usage

```
$ asciidoctor -r asciidoctor-adoc -b adoc \
    -D test/out test/black-box-docs/sample/sample.adoc
```

## Development

- To install dependencies, run `bundler install`.
- To run tests, run `bundler exec rake`.
- To build the current version, run `bundler exec rake build`; the gem will be
  placed in the `pkg/` directory.
- To release a new version:
    1. update the date in `asciidoctor-adoc.gemspec`, remove `.dev` from the
       version in `lib/asciidoctor-adoc/version.rb`, run `bundler lock`, and
       commit the changes;
    2. run `bundler exec rake release`; and
    3. increment the version in `lib/asciidoctor-adoc/version.rb` (adding
       `.dev`), run `bundler lock`, and commit the changes.
