class VirtualMachine < CloudstackCli::Base

  desc "list", "list virtual machines"
  option :account, desc: "name of the account"
  option :project, desc: "name of the project"
  option :zone, desc: "the name of the availability zone"
  option :state, desc: "state of the virtual machine"
  option :listall, desc: "list all virtual machines"
  option :storage_id, desc: "the storage ID where vm's volumes belong to"
  option :keyword, desc: "filter by keyword"
  option :command,
    desc: "command to execute for the given virtual machines",
    enum: %w(START STOP REBOOT)
  option :concurrency, type: :numeric, default: 10, aliases: '-C',
    desc: "number of concurrent command to execute"
  option :format, default: "table",
    enum: %w(table json yaml)
  def list
    if options[:project]
      options[:project_id] = find_project['id']
      options[:project] = nil
    end
    virtual_machines = client.list_virtual_machines(options)
    if virtual_machines.size < 1
      puts "No virtual_machines found."
    else
      print_virtual_machines(virtual_machines)
      execute_virtual_machines_commands(virtual_machines) if options[:command]
    end
  end

  desc "list_from_file FILE", "list virtual machines from file"
  option :command,
  desc: "command to execute for the given virtual machines",
  enum: %w(START STOP REBOOT)
  option :concurrency, type: :numeric, default: 10, aliases: '-C',
  desc: "number of concurrent command to execute"
  option :format, default: :table, enum: %w(table json yaml)
  def list_from_file(file)
    virtual_machines = parse_file(file)["virtual_machines"]
    if virtual_machines.size < 1
      puts "No virtual machines found."
    else
      print_virtual_machines(virtual_machines)
      execute_virtual_machines_commands(virtual_machines) if options[:command]
    end
  end

  desc "show NAME", "show detailed infos about a virtual machine"
  option :project
  def show(name)
    project_id = options[:project] ? find_project['id'] : nil
    unless virtual_machine = client.list_virtual_machines(name: name, project_id: project_id).first
      puts "No virtual machine found."
    else
      table = virtual_machine.map do |key, value|
        [ set_color("#{key}:", :yellow), "#{value}" ]
      end
      print_table table
    end
  end

  desc "create NAME [NAME2 ...]", "create virtual machine(s)"
  option :template, aliases: '-t', desc: "name of the template"
  option :iso, desc: "name of the iso template"
  option :offering, aliases: '-o', required: true, desc: "computing offering name"
  option :zone, aliases: '-z', required: true, desc: "availability zone name"
  option :networks, aliases: '-n', type: :array, desc: "network names"
  option :project, aliases: '-p', desc: "project name"
  option :port_rules, aliases: '-pr', type: :array,
    default: [],
    desc: "Port Forwarding Rules [public_ip]:port ..."
  option :disk_offering, desc: "disk offering (data disk for template, root disk for iso)"
  option :disk_size, desc: "disk size in GB"
  option :hypervisor, desc: "only used for iso deployments, default: vmware"
  option :keypair, desc: "the name of the ssh keypair to use"
  option :group, desc: "group name"
  option :account, desc: "account name"
  def create(*names)
    options.merge! vm_options_to_params(options)

    say "Start deploying virtual machine#{ "s" if names.size > 1 }...", :green
    jobs = names.map do |name|
      if virtual_machine = client.list_virtual_machines(name: name, project_id: options[:project_id]).first
        say "virtual_machine #{name} (#{virtual_machine["state"]}) already exists.", :yellow
        job = {
          id: 0,
          name: "Create virtual machine #{name}",
          status: 1
        }
      else
        job = {
          id: client.deploy_virtual_machine(options, {sync: true})['jobid'],
          name: "Create virtual_machine #{name}"
        }
      end
      job
    end
    watch_jobs(jobs)
    if options[:port_rules].size > 0
      say "Create port forwarding rules...", :green
      jobs = []
      names.each do |name|
        virtual_machine = client.list_virtual_machine(name: name, project_id: options[:project_id]).first
        create_port_rules(virtual_machine, options[:port_rules], false).each_with_index do |job_id, index|
          jobs << {
            id: job_id,
            name: "Create port forwarding ##{index + 1} rules for virtual machine #{virtual_machine['name']}"
          }
        end
      end
      watch_jobs(jobs)
    end
    say "Finished.", :green
  end

  desc "destroy NAME [NAME2 ..]", "destroy virtual_machine(s)"
  option :project
  option :force, desc: "destroy without asking", type: :boolean, aliases: '-f'
  option :expunge, desc: "expunge virtual_machine immediately", type: :boolean, default: false, aliases: '-E'
  def destroy(*names)
    projectid = find_project['id'] if options[:project]
    names.each do |name|
      unless virtual_machine = client.list_virtual_machines(name: name, project_id: projectid).first
        say "Virtual machine #{name} not found.", :red
      else
        ask = "Destroy #{name} (#{virtual_machine['state']})? [y/N]:"
        if options[:force] || yes?(ask, :yellow)
          say "destroying #{name} "
          client.destroy_virtual_machine(
            id: virtual_machine["id"],
            expunge: options[:expunge]
          )
          puts
        end
      end
    end
  end

  desc "bootstrap", "interactive creation of a virtual_machine with network access"
  def bootstrap
    bootstrap_server_interactive
  end

  desc "stop NAME", "stop a virtual_machine"
  option :project
  option :force
  def stop(name)
    project_id = find_project['id'] if options[:project]
    exit unless options[:force] || yes?("Stop virtual machine #{name}? [y/N]:", :magenta)
    unless virtual_machine = client.list_virtual_machines(name: name, project_id: project_id).first
      say "Virtual machine #{name} not found.", :red
      exit 1
    end
    client.stop_virtual_machine(id: virtual_machine['id'])
    puts
  end

  desc "start NAME", "start a virtual_machine"
  option :project
  def start(name)
    project_id = find_project['id'] if options[:project]
    unless virtual_machine = client.list_virtual_machines(name: name, project_id: project_id).first
      say "Virtual machine #{name} not found.", :red
      exit 1
    end
    say("Starting virtual_machine #{name}", :magenta)
    client.start_virtual_machine(id: virtual_machine['id'])
    puts
  end

  desc "reboot NAME", "reboot a virtual_machine"
  option :project
  option :force
  def reboot(name)
    project_id = find_project['id'] if options[:project]
    unless virtual_machine = client.list_virtual_machines(name: name, project_id: project_id).first
      say "Virtual machine #{name} not found.", :red
      exit 1
    end
    exit unless options[:force] || yes?("Reboot virtual_machine #{name}? [y/N]:", :magenta)
    client.reboot_virtual_machine(id: virtual_machine['id'])
    puts
  end

  no_commands do

    def print_virtual_machines(virtual_machines)
      case options[:format].to_sym
      when :yaml
        puts({'virtual_machines' => virtual_machines}.to_yaml)
      when :json
        say JSON.pretty_generate(virtual_machines: virtual_machines)
      else
        table = [["Name", "State", "Offering", "Zone", options[:project_id] ? "Project" : "Account", "IP's"]]
        virtual_machines.each do |virtual_machine|
          table << [
            virtual_machine['name'],
            virtual_machine['state'],
            virtual_machine['serviceofferingname'],
            virtual_machine['zonename'],
            options[:project_id] ? virtual_machine['project'] : virtual_machine['account'],
            virtual_machine['nic'].map { |nic| nic['ipaddress']}.join(' ')
          ]
        end
        print_table table
        say "Total number of virtual_machines: #{virtual_machines.count}"
      end
    end

    def execute_virtual_machines_commands(virtual_machines)
      command = options[:command].downcase
      unless %w(start stop reboot).include?(command)
        say "\nCommand #{options[:command]} not supported.", :red
        exit 1
      end
      exit unless yes?("\n#{command.capitalize} the virtual_machine(s) above? [y/N]:", :magenta)
      virtual_machines.each_slice(options[:concurrency]) do | batch |
        jobs = batch.map do |virtual_machine|
          args = { sync: true, account: virtual_machine['account'] }
          args[:project_id] = virtual_machine['projectid'] if virtual_machine['projectid']
          {
            id: client.send("#{command}_virtual_machine", virtual_machine['name'], args)['jobid'],
            name: "#{command.capitalize} virtual_machine #{virtual_machine['name']}"
          }
        end
        puts
        watch_jobs(jobs)
      end
    end

  end # no_commands

end