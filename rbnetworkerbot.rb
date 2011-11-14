#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), "libs", "rbnetworkerbot.rb")
require 'yaml'

## load configuration file
begin
  config = YAML.load(File.read(File.join(File.dirname(__FILE__), "rbnetworkerbot.conf")))
  raise if config['send_to'].nil? || config['email_server'].nil? || config['backup_time'].nil?
rescue
  puts "Error reading the configuration file."
  exit(false)
end

## Constants
EMAIL_TEMPLATE_LOCATION = File.join(File.dirname(__FILE__), 'templates', 'email_notification.markdown.erb')
SENDER_ADDRESS = 'backups01@bucoks.com'

todays_backups = Backups.new

# ...
=begin
summary_email = todays_backups.summary_email # this will need to return a Mail object
full_email = todays_backups.full_email
summary_email.deliver!
full_email.deliver!
=end
# or: todays_backups.summary_email.deliver!

################## OLD Script ################################################
require 'net/smtp'
#require File.join(File.dirname(__FILE__), "libs", "templates_bb.rb")

send_to = config['send_to']              # email address for backup report
#send_to = 'jdinkel@bucoks.com'          # temp email during testing
send_to_name = config['send_to_name']    # email recipients name, doesn't really matter
email_server = config['email_server']    # email server address
separate_logs = config['separate_logs']  # whether or not to put logs in a separate email from the summary, not implemented yet, sends both right now

daemon_raw = config['daemon_raw']        # location of Networker's daemon.raw log file
backup_time = config['backup_time']      # the time the backup job starts, not implemented yet - uses 6:30 PM

check_time = config['check_time']                        # how long, in minutes the script will check if the jobs completed
check_interval = config['check_interval']                # how long between checks, in minutes
check_notify_interval = config['check_notify_interval']  # how often, in minutes, to notify that the backup is not done, set equal or more than check_time to notify once, not implemented
check_notify_first = config['check_notify_first']        # how long before sending the first notification the backup is not finished, not yet implemented

days_back = config['days_back'].to_i
# allow overriding days_back from command line
ARGV.each do |arg|
  if arg[0..11] == '--days_back='
    # do a basic check to be sure it is a legit value
    if arg[12..-1] == arg[12..-1].to_i.to_s
      days_back = arg[12..-1].to_i
    else
      puts 'Invalid value for --days_back='
    end
  end
end

if config['devel_mode']
  puts 'Development mode is ON.'
  devel_mode = true
  send_to = config['devel_email'] unless config['devel_email'].nil?
else
  devel_mode = false
end

########## Main Program ###########

y = yesterday(Time.now)
days_back.times { y = yesterday(y) }

month = y.strftime("%m")
day = y.strftime("%d")
year = y.year
start_to_end_regexp = /\d+? #{month}\/#{day}\/#{year} 06:[3-5][0-9]:[0-9][0-9] PM (.|\r|\n)+ nsrd write completion notice: Writing to volume \d{6}L3 complete/
# testing regexp is below
#start_to_end_regexp = /\d+? #{month}\/#{day}\/#{year} 3:[3-5][0-9]:[0-9][0-9] PM (.|\r|\n)+ nsrd write completion notice: Writing to volume \d{6}L3 complete/
#  I should break the beginning and ending string up in to variable = /#{start_regx} (.|\r|\n)+ #{end_regx}/ would look a lot cleaner

logs = fetch_logs(start_to_end_regexp, daemon_raw)
jobs = find_jobs(logs)

# each loop will wait 'check_interval' minutes
loops = 0
until is_backup_done?(logs, jobs) || loops > check_time
  Net::SMTP.start(email_server) { |smtp| smtp.send_message(create_email(:name => send_to_name, :address => send_to, :logs => logs.join($/)), 'backups01@bucoks.com', send_to) } if loops == 110
  sleep 60 * check_interval
  loops += check_interval
  logs = fetch_logs(start_to_end_regexp, daemon_raw)
end

job_results = Array.new
jobs.each_index do |n|
  job_results[n] = "#{jobs[n]} backup result: #{job_result(jobs[n], logs)}"
end

tapes = tapes_used(logs)

### We have gathered all the info, let's bring this baby home ###

if tapes.length > 0
  unless devel_mode
    # unload any tapes mounted in a drive
    `/usr/sbin/nsrjb -u `
    # deposit any tapes from the mailbox
    `/usr/sbin/nsrjb -d -N`
    # eject the used tapes
    `/usr/sbin/nsrjb -w #{tapes.join(' ')}`
  else
    puts '...pretending to process tapes...'
  end
end

# we are going to take a break to send the email notifications and then relabel the remaining tapes

# compose the email without logs
email_params = {:name => send_to_name, :address => send_to, :email_server => email_server, :sender_address => SENDER_ADDRESS}
email_params.merge!(:tapes => tapes, :summaries => job_results)
summary_email = create_email(email_params)
# compose the email with logs
email_params.merge!(:logs => logs)
logs_email = create_email(email_params)
# send the emails
summary_email.deliver!
logs_email.deliver!

# compose and send the email without logs
#the_email = create_email( :name => send_to_name, :address => send_to, :tapes => tapes, :summary => job_results.join($/) )
#Net::SMTP.start(email_server) { |smtp| smtp.send_message(the_email, 'backups01@bucoks.com', send_to) }
# compose and send the email, with logs
#the_email = create_email( :name => send_to_name, :address => send_to, :tapes => tapes, :summary => job_results.join($/), :logs => logs.join($/) )
#Net::SMTP.start(email_server) { |smtp| smtp.send_message(the_email, 'backups01@bucoks.com', send_to) }

if tapes.length > 0
  unless devel_mode
    # mark all remaining tapes as recyclable
    #`/usr/sbin/nsrjb -Y -o recyclable -S 1-23`
    # relabel all remaining tapes, since recycling doesn't work
    `/usr/sbin/nsrjb -L -Y -S 1-23`
  else
    puts '...pretending to label tapes... and done.'
  end
end
