#!/usr/bin/env ruby

require 'yaml'

require './lib/github_fetcher.rb'
require './lib/message_builder.rb'
require './lib/slack_poster.rb'

# Entry point for the Seal!
class Seal
  def initialize(team)
    @team = team
  end

  def bark
    teams.each { |team| bark_at(team) }
  end

  private

  attr_accessor :mood

  def teams
    if @team.nil? && org_config
      org_config.keys
    else
      [@team]
    end
  end

  def bark_at(team)
    message_builder = MessageBuilder.new(pull_requests(team))
    message = message_builder.build
    channel = ENV["SLACK_CHANNEL"] ? ENV["SLACK_CHANNEL"] : team_config(team)['channel']
    ignore_seasonal_seals = team_config(team)['ignore_seasonal_seals'] ? team_config(team)['ignore_seasonal_seals'] : false
    slack = SlackPoster.new(ENV['SLACK_WEBHOOK'], channel, message_builder.poster_mood, ignore_seasonal_seals)
    slack.send_request(message)
  end

  def org_config
    @org_config ||= YAML.load_file(configuration_filename) if File.exist?(configuration_filename)
  end

  def configuration_filename
    @configuration_filename ||= "./config/#{ENV['SEAL_ORGANISATION']}.yml"
  end

  def pull_requests(team)
    config = team_config(team)
    if config
      members = config['members']
      repos = config['repos']
      use_labels = config['use_labels']
      exclude_labels = config['exclude_labels']
      exclude_titles = config['exclude_titles']
      include_labels = config['include_labels']
    else
      members = ENV['GITHUB_MEMBERS'] ? ENV['GITHUB_MEMBERS'].split(',') : []
      repos = ENV['GITHUB_REPOS'] ? ENV['GITHUB_REPOS'].split(',') : []
      use_labels = ENV['GITHUB_USE_LABELS'] ? ENV['GITHUB_USE_LABELS'].split(',') : nil
      exclude_labels = ENV['GITHUB_EXCLUDE_LABELS'] ? ENV['GITHUB_EXCLUDE_LABELS'].split(',') : nil
      exclude_titles = ENV['GITHUB_EXCLUDE_TITLES'] ? ENV['GITHUB_EXCLUDE_TITLES'].split(',') : nil
      include_labels = ENV['GITHUB_INCLUDE_LABELS'] ? ENV['GITHUB_INCLUDE_LABELS'].split(',') : nil
    end

    git = GithubFetcher.new(members,
                            repos,
                            use_labels,
                            exclude_labels,
                            exclude_titles,
                            include_labels
                           )
    git.list_pull_requests
  end

  def team_config(team)
    org_config[team] if org_config
  end
end
