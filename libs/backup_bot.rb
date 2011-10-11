#!/usr/bin/env ruby

########## Configuration ##########

send_to = 'backup_admin@bucoks.com'   # email address for backup report
#send_to = 'jdinkel@bucoks.com'        # temp email during testing
send_to_name = 'Backup Operators'     # email recipients name, doesn't really matter
email_server = '192.168.3.10'         # email server address
separate_logs = false                 # whether or not to put logs in a separate email from the summary, not implemented yet, sends both right now

daemon_raw = '/nsr/logs/daemon.raw' # location of Networker's daemon.raw log file
backup_time = ''                    # the time the backup job starts, not implemented yet - uses 6:30 PM

check_time = 340     # how long, in minutes the script will check if the jobs completed
check_interval = 10  # how long between checks, in minutes
check_notify_interval = 340 # how often, in minutes, to notify that the backup is not done, set equal or more than check_time to notify once, not implemented
check_notify_first = 110 # how long before sending the first notification the backup is not finished, not yet implemented

###################################

### This script will scrub the daemon.raw log file for the last nights backup
### job logs, starting at #{backup_time} or later.  It will then send an email
### with a summary of the tapes used and success of each job and a full
### listing of the logs, possibly in a separate email if #{separate_logs}.

### It will also import any tapes in the mailbox and then eject the tapes
### used in the backup job and mark all remaining tapes as recyclable.

########## Requires ###############
require 'net/smtp'
require '/nsr/backup_bot/libbb.rb'
require '/nsr/backup_bot/templates_bb.rb'
#require 'rubyscript2exe'
#exit if RUBYSCRIPT2EXE.is_compiling?
# rubyscript2exe is no longer maintained :( try ORCA.
###################################


########## Main Program ###########

y = yesterday(Time.now)
month = y.strftime("%m")
day = y.strftime("%d")
year = y.year
start_to_end_regexp = /\d+? #{month}\/#{day}\/#{year} 06:[3-5][0-9]:[0-9][0-9] PM (.|\r|\n)+ nsrd write completion notice: Writing to volume \d{6}L3 complete/

logs = fetch_logs(start_to_end_regexp, daemon_raw)
jobs = find_jobs(logs)

# each loop will wait 'check_interval' minutes
loops = 0
until is_backup_done?(logs, jobs) || loops > check_time
  Net::SMTP.start(email_server) { |smtp| smtp.send_message(create_email(:name => send_to_name, :address => send_to, :logs => logs.join($/)), 'mans02@bucoks.com', send_to) } if loops == 110
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
  # unload any tapes mounted in a drive
  `/usr/sbin/nsrjb -u `
  # deposit any tapes from the mailbox
  `/usr/sbin/nsrjb -d -N`
  # eject the used tapes
  `/usr/sbin/nsrjb -w #{tapes.join(' ')}`
end

# we are going to take a break to send the email notifications and then relabel the remaining tapes

# compose and send the email without logs
the_email = create_email( :name => send_to_name, :address => send_to, :tapes => tapes.join(', '), :summary => job_results.join($/) )
Net::SMTP.start(email_server) { |smtp| smtp.send_message(the_email, 'mans02@bucoks.com', send_to) }
# compose and send the email, with logs
the_email = create_email( :name => send_to_name, :address => send_to, :tapes => tapes.join(', '), :summary => job_results.join($/), :logs => logs.join($/) )
Net::SMTP.start(email_server) { |smtp| smtp.send_message(the_email, 'mans02@bucoks.com', send_to) }

if tapes.length > 0
  # mark all remaining tapes as recyclable
  #`/usr/sbin/nsrjb -Y -o recyclable -S 1-23`
  # relabel all remaining tapes, since recycling doesn't work
  `/usr/sbin/nsrjb -L -Y -S 1-23`
end

=begin
# Inventory everything, just to be sure
#`nsrjb -I -E`
#this command does not work, for some reason ti seems to crash the tape library
# I would prefer to do this first thing before unload tapes to make sure there
# hasn't been any manual modifications to the tape drive.
=end
