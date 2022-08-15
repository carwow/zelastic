# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## How do I make a good changelog?

### Guiding Principles

- Changelogs are for humans, not machines.
- There should be an entry for every single version.
- The same types of changes should be grouped.
- Versions and sections should be linkable.
- The latest version comes first.
- The release date of each version is displayed.
- Keep an `Unreleased` section at the top to track upcoming changes.

### Types of changes

- `Added` for new features.
- `Changed` for changes in existing functionality.
- `Deprecated` for soon-to-be removed features.
- `Removed` for now removed features.
- `Fixed` for any bug fixes.
- `Security` in case of vulnerabilities.

## [Unreleased]

## Unreleased: [1.0.0] - 2022-08-XX
### Added
- Support for Ruby 3 (and keep support for 2.7).
- Support for Elasticsearch v8 (and keep support for v7).
- Support setting a logger in `Config`.
- Support refresh on `IndexManager#populate_index`.
- Support Proc in `Config#data_source` so it can be lazily evaluated.

### Removed
- Drop support for Ruby 2.6.
- Drop support for Elasticsearch v5 and v6.

[Unreleased]: https://github.com/carwow/zelastic/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/carwow/zelastic/releases/tag/v1.0.0
