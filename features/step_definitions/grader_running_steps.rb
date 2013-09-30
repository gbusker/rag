require 'tempfile'

Given(/^The solution file "(.*?)"$/) do |solution_file|
  f = File.open("#{$APP}/#{solution_file}")
  @solution_path = solution_file
end

Given(/^The spec file "(.*)"$/) do |spec_file|
  @spec_path = spec_file
end

When(/^I run the local_autograder with "(.*)"$/) do |grader_type|
  @output = `#{$APP}/run_local_autograder #{@solution_path} #{@spec_path} #{grader_type}`
end

Then(/^the message should match \/(.*)\/$/) do |regexp|
  @output.should match(regexp)
end

Then(/^the score should be (.*)$/) do |score|
  @output.should match(/Score: #{score}/)
end
