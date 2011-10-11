########## Methods ################
# methods used by backup_bot

def yesterday(today)
  yday = today
  yday = yday - ( 24 * 60 * 60 ) until  ( yday.day != today.day )
  return yday
end

def my_array_index(array, regexp)
  array.each_index do |n|
    if (array[n] =~ regexp) == 0
      return n
    end
  end
  return 0
end

def my_array_index_end(array, regexp)
  array.each_index do |n|
    unless (array[-(n+1)] =~ regexp) == nil
      if (array[-(n+1)] =~ regexp) >= 0
        return -(n+1)
      end
    end
  end
  return 0
end

def fetch_the_logs(start, ending, log_file)
  #the_logs = File.open(log_file).collect { |line| line.chomp }
  the_logs = log_file.split($/)
  the_logs = the_logs[my_array_index(the_logs, start)..-1]
  return the_logs[0..my_array_index_end(the_logs, ending)]
end

# Checks the logs to be sure all backup jobs are completed.  The logs should
# be passed in as an array of lines from the log.  The jobs should be passed
# in as an array of the job names.
def is_backup_done?(the_logs, the_jobs)
  status = true # assume the backup is done unless any job changes it to false
  the_jobs.each do |job|
    status = false unless / nsrd savegroup (failure alert|notice): #{job} (Completed\/Aborted|completed), Total /.match(the_logs.join)
  end
  return status
end

# Determines if the job finished as a success or failure
def job_result(job_name, the_logs)
  the_logs.each do |line|
    if / nsrd savegroup (notice|alert): #{job_name} completed, Total /.match(line)
      return /Total \d+? client\(s\), .+ed\./.match(line).to_s
    end
  end
return 'I don\'t know'
end

def tapes_used(the_logs)
  # figure out which tapes were used in the backup jobs
  the_tapes = Array.new
  the_logs.each do |line|
    if /saving to pool \S+ \(......L3\)/.match(line)
      tape = /......L3/.match(line).to_s
      the_tapes = the_tapes.push(tape) unless the_tapes.include?(tape)
    end 
  end
  return the_tapes
end

def fetch_logs(expression, raw_log_file)
  expression.match(`/usr/bin/nsr_render_log -L en_US.iso88591 #{raw_log_file}`).to_s.split($/)
end

def find_jobs(the_logs)
  jobs = Array.new
  the_logs.each do |line|
    if /savegroup info: starting .+ \(with \d+ client\(s\)\)/.match(line)
      jobs.push($~.to_s[25...-(/ \(with \d+ client\(s\)\)/.match(line).to_s.length)])
    end
  end
  jobs.uniq
end

###################################