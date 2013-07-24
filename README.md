# Cloudstack CLI

Cloudstack CLI is a [CloudStack](http://cloudstack.apache.org/) API client written in Ruby.

## Installation

Install the cloudstack-cli gem:

    $ gem install cloudstack-cli

## Setup

Create the initial configuration:

	$ cs setup

cloudstack-cli expects to find a configuartion file with the API URL and your CloudStack credentials in your home directory named .cloudstack-cli.yml. If the file is located elsewhere you can specify the loaction using the --config option.

Example content of the configuration file:

    :url:         "https://my-cloudstack-server/client/api/"
	:api_key:     "cloudstack-api-key"
	:secret_key:  "cloudstack-api-secret"

## Usage

Please see http://rubydoc.info/gems/cloudstack-cli/0.0.3/frames

See the help screen:

    $ cs

### Example 1

Bootsrap a server:

    $ cs server create server01 --zone ZUERICH_IX --port-forwarding 193.218.104.10:22 193.218.104.10:80 --template CentOS-6.4-x64-v1.4 --offering 1cpu_1gb --networks M_Demo

### Example 2

Run a custom API command:

    $ cs command listAlerts type=8

### Example 3

Sort all computing offerings by CPU and Memory grouped my Domain:

    $ cs offering sort

### Example 4

Stop all virtual routers of project Demo (you could filter by Zone too):
(This command is helpful if you have to deploy new versions of Cloudstack when using redumdant routers)

    $ cs router list --project Demo --status running --redundant-state BACKUP --command stop

Hint: You can watch the status of the command with watch.

    $ watch -n cs router list --project Demo


## References
-  [Cloudstack API documentation](http://cloudstack.apache.org/docs/api/apidocs-4.1/TOC_Root_Admin.html)
-  This tool was inspired by the Knife extension for Cloudstack: [knife-cloudstack](https://github.com/CloudStack-extras/knife-cloudstack)


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## License

Released under the MIT License. See the [LICENSE](https://bitbucket.org/swisstxt/cloudstack-cli/raw/master/LICENSE.txt) file for further details.
