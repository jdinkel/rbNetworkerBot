require 'erubis'
# templates for creating emails, so I don't have to dirty up the main program
# file with all this formatting.

def create_email(params)
  # params should be a hash with name, address, tapes, summary, logs

if params[:summary] && params[:tapes]
  subject = 'Backup Job results'
  subject = subject + ', with logs' if params[:logs]
else
  subject = 'Backup Job Not Finished'
end

if params[:tapes].length == 1
  an_s = ''
else
  an_s = 's'
end

  the_email = <<END_OF_EMAIL
From: The Backup Server <mans02@bucoks.com>
To: <%= params[:name] %> <<%= params[:address] %>>
Subject: <%= subject %>

<% if params[:summary] && params[:tapes] %>
SUMMARY:
==================================================

Tape<%= an_s %> used: <%= params[:tapes].join(', ') %>

<%= params[:summary] %>


==================================================
<% unless params[:logs] %>

Please put exactly <%= params[:tapes].length %> tape<%= an_s %> back in the tape library.
<% else %>

The full logs follow:

<%= params[:logs] %>
<% end %>
<% else %>
The backup job has not finished.  Here are the logs so far:

<%= params[:logs] %>
<% end %>
END_OF_EMAIL

  Erubis::FastEruby.new(the_email).result(:params=>params, :an_s=>an_s, :subject=>subject)
end
