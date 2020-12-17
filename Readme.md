# WWTD: Travis simulator [![Build Status](https://travis-ci.org/grosser/wwtd.svg?branch=master)](https://travis-ci.org/grosser/wwtd)

Reads your `.travis.yml` and runs what Travis would run (using [rvm], [rbenv], or [chruby]).  No more waiting for build emails!

![Results](assets/results.png?raw=true)

[rvm]: https://github.com/rvm/rvm
[rbenv]: https://github.com/rbenv/rbenv
[chruby]: https://github.com/postmodern/chruby


## Install

```bash
gem install wwtd
```

(bracelets sold separately)


## Usage

```bash
wwtd                # Run all gemfiles with all Ruby versions
wwtd --local        # Run all gemfiles with current Ruby version => get rid of Appraisal gem!
wwtd --ignore env   # Ignore env settings
wwtd --use install  # Use dangerous travis fields like before_install/install/before_script/...
wwtd --parallel 2   # Run in parallel
wwtd --only-bundle  # Bundle all gemfiles
wwtd --help         # Display help, and learn about other options
wwtd --version      # Display version
```

### Rake

```ruby
require 'wwtd/tasks'
```

```bash
rake wwtd         # Run all gemfiles with all Ruby versions
rake wwtd:local   # Run all gemfiles with current Ruby version => get rid of Appraisal gem!
rake wwtd:bundle  # Bundle all gemfiles
```

### Tips

- `./vendor/bundle` is created if you have committed a lock file.  Add the lock file to `.gitignore`, or better yet to your global `.gitignore`.
- If you do not want `--deployment` but do want a lock file, add `bundler_args: ""` to your `.travis.yml`.

### Parallel

- Might show errors that do not happen in serial builds
- Runs number-of-processors builds in parallel
- Runs each configuration in a separate process
- Sets `ENV["TEST_ENV_NUMBER"]` (where 1 = "", 2 = "2", etc) so you can do `db = "test#{ENV['TEST_ENV_NUMBER']}"`

```bash
wwtd --parallel  # same result, but number-of-processors faster :)
```


## Contribution

Run tests with:

```bash
bundle
bundle exec rake
```

The tests need different Ruby versions to be installed.  If they do not run locally, you can use Vagrant instead:

```bash
vagrant up # it will take a while
vagrant ssh
cd /vagrant
bundle exec rake
```


## Authors

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
