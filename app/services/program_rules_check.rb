# Code-side guard on AI output (not trusted to the model): the three hard rules of a MentorFire Program draft
# that can be checked without reading for meaning.
#
#   1. The Program has exactly the number of sessions the mentor asked for, numbered 1 to n in order.
#      Production's program_drafter: "Never write more sessions than asked"; an engagement ends where it says.
#   2. In every session, the agenda minutes add up to at most the session length. Production's
#      session_agenda_builder: items "totalling at most the session length".
#   3. Every task is given to the mentor or the mentee, never to "either", "both", or a named person.
#      Each task in the demo has one owner; production's third role, "either", is dropped (see the demo spec §8).
#
# Also checks that a task's session_number points at a real session (1..n) or the program level (0).
#
# The controller's parser checks the JSON shape first (types, required fields, list sizes), then calls
# ProgramRulesCheck.problems; the first problem becomes the failure_reason the member sees.
# evals/cases/mentorfire_program_v1.yml mirrors each rule as a deterministic check, because evals:run calls the
# template directly and never reaches this parser.
module ProgramRulesCheck
  module_function

  # sessions: [{ "number" => Integer, "agenda" => [{ "item" => String, "minutes" => Integer }] }]
  # tasks:    [{ "name" => String, "session_number" => Integer, "assignee" => String }]
  # Returns a list of plain-English problems, empty when the draft keeps every rule.
  def problems(sessions:, tasks:, sessions_count:, session_minutes:)
    found = []

    if sessions.size != sessions_count
      found << "The draft had #{sessions.size} #{'session'.pluralize(sessions.size)}, not the #{sessions_count} you asked for"
    elsif sessions.map { |s| s["number"] } != (1..sessions_count).to_a
      found << "The sessions were not numbered 1 to #{sessions_count} in order"
    end

    sessions.each do |session|
      total = Array(session["agenda"]).sum { |a| a["minutes"].to_i }
      next if total <= session_minutes
      found << "Session #{session['number']}'s agenda adds up to #{total} minutes, " \
               "more than the #{session_minutes}-minute session"
    end

    tasks.each_with_index do |task, i|
      unless ProgramDraft::ASSIGNEES.include?(task["assignee"])
        found << "Task #{i + 1} is given to \"#{task['assignee'].to_s.truncate(30)}\", not the mentor or the mentee"
      end
      unless task["session_number"].between?(0, sessions_count)
        found << "Task #{i + 1} is placed on session #{task['session_number']}, which does not exist"
      end
    end

    found
  end

  def clean?(**args) = problems(**args).empty?
end
