#!/usr/bin/env ruby

########## Requires ###############
#require '/nsr/backup_bot/libbb.rb'
###################################


########## Main Program ###########

#tapes = %w{}

### We have gathered all the info, let's bring this baby home ###

#if tapes.length > 0
#  # unload any tapes mounted in a drive
#  `/usr/sbin/nsrjb -u `
  # deposit any tapes from the mailbox
  `/usr/sbin/nsrjb -d -N`
  # eject the used tapes
#  `/usr/sbin/nsrjb -w #{tapes.join(' ')}`

  # relabel all remaining tapes, since recycling doesn't work
  `/usr/sbin/nsrjb -L -Y -S 1-23`
#end
