#!/usr/bin/env ruby

require "fileutils"
require "pathname"
require_relative "../author"
require_relative "../commit"
require_relative "../database"
require_relative "../entry"
require_relative "../refs"
require_relative "../tree"
require_relative "../workspace"

command = ARGV.shift

case command
when "init"
  path = ARGV.fetch(0, Dir.getwd)

  root_path = Pathname.new(File.expand_path(path))
  git_path = root_path.join(".git")

  ["objects", "refs"].each do |dir|
    begin
      FileUtils.mkdir_p(git_path.join(dir))
    rescue Errno::EACCES => error
      $stderr.puts "fatal: #{ error.message }"
    end
  end

  puts "Initialized empty Jit repository in #{ git_path }"
  exit 0
when "commit"
  root_path = Pathname.new(Dir.getwd)  # ~/Coding/jit
  git_path = root_path.join(".git")    # ~/Coding/jit/.git
  db_path = git_path.join("objects")   # ~/Coding/jit/.git/objects

  workspace = Workspace.new(root_path)
  database = Database.new(db_path)
  refs = Refs.new(git_path)

  entries = workspace.list_files.map do |path|
    data = workspace.read_file(path)
    blob = Blob.new(data)

    database.store(blob)

    stat = workspace.stat_file(path)
    Entry.new(path, blob.oid, stat)
  end

  tree = Tree.new(entries)
  database.store(tree)

  parent  = refs.read_head
  name    = ENV.fetch("GIT_AUTHOR_NAME")
  email   = ENV.fetch("GIT_AUTHOR_EMAIL")
  author  = Author.new(name, email, Time.now)
  message = $stdin.read

  commit = Commit.new(parent, tree.oid, author, message)
  database.store(commit)
  refs.update_head(commit.oid)

  is_root = parent.nil? ? "(root-commit) " : ""

  puts "[#{ is_root }#{ commit.oid }] #{ message.lines.first }"
  exit 0
else
  $stderr.puts "jit: '#{ command }' is not a jit command."
end
