require "rails_helper"

RSpec.describe ProgramRulesCheck do
  def session(number, *minutes)
    { "number" => number, "agenda" => minutes.map { |m| { "item" => "Item", "minutes" => m } } }
  end

  def task(assignee = "mentee", session_number = 1)
    { "name" => "A task", "session_number" => session_number, "assignee" => assignee }
  end

  let(:sessions) { [ session(1, 20, 20), session(2, 30, 15), session(3, 45) ] }
  let(:tasks)    { [ task("mentor", 0), task("mentee", 3) ] }

  def problems(sessions: self.sessions, tasks: self.tasks, count: 3, minutes: 45)
    described_class.problems(sessions:, tasks:, sessions_count: count, session_minutes: minutes)
  end

  it "passes a draft that keeps every rule, including an agenda that uses the full session" do
    expect(problems).to eq([])
    expect(described_class.clean?(sessions:, tasks:, sessions_count: 3, session_minutes: 45)).to be(true)
  end

  describe "session count" do
    it "fails more sessions than asked" do
      expect(problems(count: 2).first).to eq("The draft had 3 sessions, not the 2 you asked for")
    end

    it "fails fewer sessions than asked" do
      expect(problems(count: 4).first).to eq("The draft had 3 sessions, not the 4 you asked for")
    end

    it "fails sessions that are not numbered 1 to n in order" do
      reordered = [ sessions[1], sessions[0], sessions[2] ]
      expect(problems(sessions: reordered)).to include("The sessions were not numbered 1 to 3 in order")
    end
  end

  describe "agenda minutes" do
    it "fails a session whose agenda runs over the session length" do
      over = [ sessions[0], session(2, 30, 20), sessions[2] ]
      expect(problems(sessions: over)).to eq([ "Session 2's agenda adds up to 50 minutes, more than the 45-minute session" ])
    end
  end

  describe "assignee" do
    %w[either both coordinator Mentor].each do |assignee|
      it "fails a task given to #{assignee.inspect}" do
        expect(problems(tasks: [ task(assignee) ])).to eq([ "Task 1 is given to \"#{assignee}\", not the mentor or the mentee" ])
      end
    end
  end

  describe "task placement" do
    it "fails a task placed on a session that does not exist" do
      expect(problems(tasks: [ task("mentee", 4) ])).to eq([ "Task 1 is placed on session 4, which does not exist" ])
    end

    it "allows session 0 (program level) and the last session" do
      expect(problems(tasks: [ task("mentee", 0), task("mentor", 3) ])).to eq([])
    end
  end
end
