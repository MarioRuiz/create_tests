# CreateTests

[![Gem Version](https://badge.fury.io/rb/create_tests.svg)](https://rubygems.org/gems/create_tests)
[![Build Status](https://travis-ci.com/MarioRuiz/create_tests.svg?branch=master)](https://github.com/MarioRuiz/create_tests)
[![Coverage Status](https://coveralls.io/repos/github/MarioRuiz/create_tests/badge.svg?branch=master)](https://coveralls.io/github/MarioRuiz/create_tests?branch=master)

Create Tests automatically from a Requests file. Perfect to be used with the result from importing a Swagger file using the open_api_import gem. Now we are supporting RSpec.

More info about the Request Hashes: https://github.com/MarioRuiz/Request-Hash

If you want to know how to import Swagger / Open API files in just a couple of seconds and transform them into Request Ruby Hashes: https://github.com/MarioRuiz/open_api_import

We strongly recommend to use nice_http gem for your tests: https://github.com/MarioRuiz/nice_http


## Installation

Install it yourself as:

    $ gem install create_tests


Take in consideration create_tests gem is using the 'rufo' gem that executes in command line the `rufo` command. In case you experience any trouble with it, visit: https://github.com/ruby-formatter/rufo

## Usage

After installation you can run using command line executable or just from Ruby.

The execution will create an spec folder where you will have all the RSpec tests. Also it will be added to that file a `helper.rb` file.

Also a `settings` folder that will contain a `general.rb` file that will be required by the tests.

### Executable

For help and see the options, run in command line / bash: `create_tests -h`

Example: 
```bash
 create_tests ./requests/uber.yaml.rb
```

### Ruby file
Write your ruby code on a file and in command line/bash: `ruby my_file.rb`

This is an example:

```ruby
  require 'create_tests'
  
  CreateTests.from "./requests/uber.yaml.rb"

```

## Example

On this example we will be creating tests for the Uber API using the Swagger / Open API file.

1. Create a folder in your computer called for example `create_tests_example`

2. Copy the file that we have on `./example/requests/uber.yaml` into a folder called `requests` inside `create_tests_example folder`.

3. First we will convert this Swagger file into Requests Hashes by running from `create_tests_example` folder:
```bash
open_api_import ./requests/uber.yaml -fT
```
Now all the Request files were created on the `requests` folder:
```
** Generated files that contain the code of the requests after importing the Swagger file: 
  - requests/uber.yaml_Products.rb
  - requests/uber.yaml_Estimates.rb
  - requests/uber.yaml_User.rb
** File that contains all the requires for all Request files: 
   - requests/uber.yaml.rb 
```

4. Now we will create the tests by running:
```bash
create_tests ./requests/uber.yaml.rb
```

5. All your tests will be on `spec` folder, and a `general.rb` file inside `settings` folder was created and also take a look at your `helper.rb` file on `spec` folder.
```
- Logs: ./requests/uber.yaml.rb_create_tests.log
** Pay attention, if any of the test files exist or the help file exist only will be added the tests, methods that are missing.
- Settings: ./settings/general.rb
- Test created: ./spec/User/profile_user_spec.rb
- Test created: ./spec/User/activity_user_spec.rb
- Test created: ./spec/Products/list_products_spec.rb
- Test created: ./spec/Estimates/price_estimates_spec.rb
- Test created: ./spec/Estimates/time_estimates_spec.rb
- Helper: ./spec/helper.rb
```

You can see a reproduction of what we did before on here: https://github.com/MarioRuiz/create_tests/tree/master/example

## Parameters

The parameters can be supplied alone or with other parameters. In case a parameter is not supplied then it will be used the default value.

### mode

Accepts three different options: :overwrite, :dont_overwrite and :append. By default :append. 

  append: In case the test file already exists will be only adding those tests that are missing from that file. If the test file doesn't exist, will be created and added all tests.

  dont_overwrite: In case the test file exists any change will be done. If it doesn't exist then it will be created.

  overwrite: In case the file exist you will loose the current code and a new code will be created. Take in consideration that all previous content will be deleted.
  If it doesn't exist the test file then it will be created.

```ruby
  require 'create_tests'

  CreateTests.from "./requests/uber.yaml.rb", mode: :overwrite

```


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marioruiz/create_tests.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).