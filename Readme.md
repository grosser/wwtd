WWTD: Travis simulator - faster + no more waiting for build emails.<br/>
Reads your .travis.yml and runs what travis would run (via rvm/rbenv/chruby).

![Results](assets/results.png?raw=true)

Install
=======

```Bash
gem install wwtd
```
(bracelets sold separately)

Usage
=====

```Bash
wwtd
START gemfile: gemfiles/rails32.gemfile, rvm: 2.0
....
START gemfile: gemfiles/rails32.gemfile, rvm: 1.9.3
....
Results:
SUCCESS gemfile: gemfiles/rails32.gemfile, rvm: 2.0
FAILURE gemfile: gemfiles/rails32.gemfile, rvm: 1.9.3
```

### Options
```Bash
wwtd --local        # Run all gemfiles on current ruby -> get rid of Appraisal
wwtd --ignore env   # Ignore env settings
wwtd --bundle       # Bundle all gemfiles
```

### Rake

```
require 'wwtd/tasks'
```

 - run all gemfiles and ruby versions `rake wwtd`
 - run all locally available ruby verions `rake wwtd:bundle`
 - bundle all gemfiles `rake wwtd:bundle`

### Tips
 - vendor/bundle is created if you have a committed lock file, add it to `.gitignore` or better yet to your global `.gitignore`.
 - if you do not want `--deployment` but want a lockfile add `bundler_args: ""` to your .travis.yml

### Parallel

 - might show errors that do not happen in serial builds
 - runs number-of-processors builds in parallel
 - runs each configuration in a separate process
 - adds `ENV["TEST_ENV_NUMBER"]` (1 = "" 2 = "2") so you can do `db = "test#{ENV['TEST_ENV_NUMBER']}"`

```Bash
wwtd --parallel
same result, but number-of-processors faster :)
```

Contribution
=======

Run tests with:

```
bundle
bundle exec rake
```

The tests need different ruby versions to be installed,
if they do not run locally you can use vagrant instead.

```
vagrant up # it will take a while
vagrant ssh
cd /vagrant
bundle exec rake
```

Authors
=======

### [Contributors](https://github.com/grosser/wwtd/contributors)
 - [Joshua Kovach](https://github.com/shekibobo)
 - [Kris Leech](https://github.com/krisleech)
 - [Eirik Dentz Sinclair](https://github.com/edsinclair)
 - [Lukasz Krystkowiak](https://github.com/lukkry)
 - [Jeff Dean](https://github.com/zilkey)
 - [Ben Osheroff](https://github.com/osheroff)
 - [David Rodríguez](https://github.com/deivid-rodriguez)
 - [stereobooster](https://github.com/stereobooster)


[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/wwtd.png)](https://travis-ci.org/grosser/wwtd)
