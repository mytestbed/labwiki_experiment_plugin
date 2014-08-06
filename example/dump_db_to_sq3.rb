#!/usr/bin/ruby

# Copyright (c) 2014 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# Simple example of a script to dump an entire experiment database from a
# PostreSQL server into dump file suitable for importing into SQLite3
# 
# This could be used to customise the 'Download/Dump Data' button of the 
# 'Execute' panel of Labwiki.
#
# This requires pg_dump command line app to be available on the path

pdb=ARGV[0] # The only argument to that script is the database name
file="/var/www/#{pdb}.sq3"  # Path to the output file
phost = "foo.com" # Hostname for the PostgreSQL server holding the data
puser = "bar" # PostgreSQL user to use
# PSQL password: either use a pgpass file or set the PGPASSWORD env variable

# Dump the database in PostgreSQL format
dump="/usr/bin/pg_dump -h #{phost} --inserts -U #{puser} #{pdb} -f #{file}"

# Get rid of all PostgreSQL specific commands inside the dump
out=`#{dump}`
result = []
lines = File.readlines(file)
lines.each do | line |
  next if line =~ /SELECT pg_catalog.setval/  # sequence value's
  next if line =~ /SET /                      # postgres specific config
  next if line =~ /--/                        # comment
  next if line =~ /ALTER/                        # comment
  next if line =~ /CREATE EXTENSION/                        # comment
  next if line =~ /CREATE ON EXTENSION/                        # comment
  next if line =~ /COMMENT ON EXTENSION/                        # comment
  next if line =~ /CREATE SEQUENCE/                        # comment
  next if line =~ /START WITH/                        # comment
  next if line =~ /INCREMENT/                        # comment
  next if line =~ /NO MINVALUE/                        # comment
  next if line =~ /NO MAXVALUE/                        # comment
  next if line =~ /CACHE/                        # comment
  next if line =~ /ADD CONSTRAINT/                        # comment
  next if line =~ /REVOKE ALL/                        # comment
  next if line =~ /GRANT ALL/

  # replace true and false for 't' and 'f'
  line.gsub!("true","'t'")
  line.gsub!("false","'f'")
  result << line
end

# Write the resulting file suitable for SQLite3 import.
File.open(file, "w") do |f|
  # Add BEGIN and END so we add it to 1 transaction. Increase speed!
  f.puts("BEGIN;")
  result.each{|line| f.puts(line) unless line=="\n"}
  f.puts("END;")
end
