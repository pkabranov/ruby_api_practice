# frozen_string_literal: true

require 'base64'
require 'faraday'
require 'pry'

filename = 'arsenal.txt'

base_url = 'https://api.github.com'
github_token = ''
get_or_update_file_contents_url = "/repos/pkabranov/wdb_ducks/contents/#{filename}"
get_refs_heads_url = '/repos/pkabranov/wdb_ducks/git/refs/heads'
create_new_branch_url = '/repos/pkabranov/wdb_ducks/git/refs'
create_pr_url = '/repos/pkabranov/wdb_ducks/pulls'

conn = Faraday.new(
  url: base_url,
  headers: {
    'Authorization' => "Bearer #{github_token}",
    'Content-Type' => 'application/json'
  }
)

# Create new branch
def create_new_branch(branch_name, conn, get_refs_heads_url, create_new_branch_url)
  response = conn.get(get_refs_heads_url)
  main_sha = ''
  ref = "refs/heads/#{branch_name}"
  json_body = JSON.parse response.body
  json_body.each do |x|
    main_sha = x['object']['sha'] if x['ref'] == 'refs/heads/master'
  end

  conn.post(create_new_branch_url) do |req|
    req.body = { ref: ref, sha: main_sha }.to_json
  end
end

# Create pr
def create_pr(title, branch_name, pr_body, conn, create_pr_url)
  conn.post(create_pr_url) do |req|
    req.body = { title: title,
                 head: branch_name,
                 body: pr_body,
                 base: 'master' }.to_json
  end
end

# 1. Create the new branch
branch_name = 'alan'
create_new_branch(branch_name, conn, get_refs_heads_url, create_new_branch_url)

# 2. Get file content in plaintext
response = conn.get(get_or_update_file_contents_url)
json_body = JSON.parse response.body
blob_sha = json_body['sha']
enc_content = json_body['content']
plain_content = Base64.decode64(enc_content)

# If file doesn't exist, write current contents to new file
File.open(filename, 'w') { |f| f.write plain_content } unless File.exist?(filename)

# Append the new content
plain_content_to_append = 'skibidi'
File.open(filename, 'a') { |f| f.puts plain_content_to_append }

plain_new_content = File.read(filename)
enc_new_content = Base64.encode64(plain_new_content)

# 3. Update the file content
conn.put(get_or_update_file_contents_url) do |req|
  commit_message = 'skibidi'
  req.body = { message: commit_message,
               content: enc_new_content,
               branch: branch_name,
               sha: blob_sha }.to_json
end

# 4. Create a new pull request
title = 'new pr'
pr_body = 'pr body'
create_pr(title, branch_name, pr_body, conn, create_pr_url)
