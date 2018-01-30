#!/usr/bin/expect

# Provide password answers to prompts for saslpasswd2 interactive prompts

set domain [lindex $argv 0]
set username [lindex $argv 1]
set password [lindex $argv 2]

puts "Running command: saslpasswd2 -c -u $domain $username"

spawn saslpasswd2 -c -u $domain $username

while true {
    expect {
        "Password:" {
            send "$password\r"
        }
        "Again (for verification):" {
            send "$password\r"
        }
        eof {
            break
        }
    }
}
