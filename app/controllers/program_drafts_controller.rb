class ProgramDraftsController < ApplicationController
  TEMPLATE = "mentorfire_program_v1".freeze

  before_action :set_mentor_offer

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }

  # shared/_ai_error's "Try again" can land here with a GET; send it back to the offer.
  def index
    redirect_to mentor_offer_path(@mentor_offer)
  end

  def show
    @program_draft = @mentor_offer.program_drafts.find(params[:id])
  end

  def create
    raw = GeminiService.generate(template: TEMPLATE, variables: @mentor_offer.ai_variables)

    @program_draft = @mentor_offer.program_drafts.create!(
      status:          "pending",
      gemini_raw:      raw,
      generated_at:    Time.current,
      sessions_count:  @mentor_offer.sessions_count,
      session_minutes: @mentor_offer.session_minutes
    )

    result = parse_program!(raw)
    @program_draft.update!(result.merge(status: "completed"))
    redirect_to mentor_offer_program_draft_path(@mentor_offer, @program_draft)

  rescue ParseError => e
    @program_draft.update!(status: "failed", failure_reason: e.message.truncate(250), gemini_raw: e.raw)
    redirect_to mentor_offer_program_draft_path(@mentor_offer, @program_draft)

  rescue GeminiService::BudgetExceededError
    render "shared/ai_error_page", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity

  rescue GeminiService::GatekeeperError
    render "shared/ai_error_page", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity

  rescue GeminiService::OutputGuardError
    render "shared/ai_error_page", locals: { error_type: :output_blocked }, status: :unprocessable_entity

  rescue GeminiService::TimeoutError
    render "shared/ai_error_page", locals: { error_type: :timeout }, status: :unprocessable_entity

  rescue GeminiService::GeminiError
    render "shared/ai_error_page", locals: { error_type: :error }, status: :unprocessable_entity
  end

  private

  def set_mentor_offer
    @mentor_offer = current_user.mentor_offers.find(params[:mentor_offer_id])
  end

  ParseError = Class.new(StandardError) do
    attr_reader :raw
    def initialize(msg, raw:)
      super(msg)
      @raw = raw
    end
  end

  # Validates the mentorfire_program_v1 JSON and returns the ProgramDraft attributes.
  # Shape first (types, required fields, list sizes), then the hard rules in ProgramRulesCheck: the session count
  # the mentor asked for, agenda minutes within the session length, and every task given to the mentor or mentee.
  def parse_program!(raw)
    fail_parse = ->(msg) { raise ParseError.new(msg, raw: raw) }

    stripped = raw.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    parsed   = JSON.parse(stripped)
    fail_parse.("Expected a JSON object") unless parsed.is_a?(Hash)

    name, purpose, outcome = parsed.values_at("name", "purpose", "outcome_statement").map { |v| text(v) }
    fail_parse.("name is missing")              unless name
    fail_parse.("purpose is missing")           unless purpose
    fail_parse.("outcome_statement is missing") unless outcome

    sessions = parsed["sessions"]
    fail_parse.("sessions must be a list") unless sessions.is_a?(Array) && sessions.any?
    sessions = sessions.map.with_index(1) do |session, i|
      fail_parse.("Session #{i} is not an object") unless session.is_a?(Hash)
      number = whole_number(session["number"])
      title, aim = text(session["title"]), text(session["aim"])
      fail_parse.("Session #{i} needs a number, a title and an aim") unless number && title && aim

      agenda = session["agenda"]
      unless agenda.is_a?(Array) && agenda.size.between?(3, 6)
        fail_parse.("Session #{i} needs 3-6 agenda items, got #{Array(agenda).size}")
      end
      agenda = agenda.map do |a|
        item, minutes = a.is_a?(Hash) ? [ text(a["item"]), whole_number(a["minutes"]) ] : []
        fail_parse.("Session #{i} has an agenda item without text or positive minutes") unless item && minutes&.positive?
        { "item" => item, "minutes" => minutes }
      end
      { "number" => number, "title" => title, "aim" => aim, "agenda" => agenda }
    end

    tasks = parsed["tasks"]
    unless tasks.is_a?(Array) && tasks.size.between?(6, 12)
      fail_parse.("Expected 6-12 tasks, got #{Array(tasks).size}")
    end
    tasks = tasks.map.with_index(1) do |task, i|
      task_name, session_number = task.is_a?(Hash) ? [ text(task["name"]), whole_number(task["session_number"]) ] : []
      fail_parse.("Task #{i} needs a name and a session_number") unless task_name && session_number
      { "name" => task_name, "session_number" => session_number, "assignee" => task["assignee"].to_s.strip.downcase }
    end

    questions = parsed["first_intro_questions"]
    unless questions.is_a?(Array) && questions.size == 3 && questions.all? { |q| text(q) }
      fail_parse.("Expected exactly 3 first_intro_questions, got #{Array(questions).size}")
    end

    problems = ProgramRulesCheck.problems(
      sessions:        sessions,
      tasks:           tasks,
      sessions_count:  @mentor_offer.sessions_count,
      session_minutes: @mentor_offer.session_minutes
    )
    fail_parse.(problems.first) if problems.any?

    {
      name:                  name,
      purpose:               purpose,
      outcome_statement:     outcome,
      sessions:              sessions,
      tasks:                 tasks,
      first_intro_questions: questions.map(&:strip)
    }
  rescue JSON::ParserError => e
    raise ParseError.new("JSON parse failed: #{e.message.truncate(120)}", raw: raw)
  end

  # A non-blank string, stripped; nil for anything else.
  def text(value)
    value.strip if value.is_a?(String) && value.strip.present?
  end

  # An Integer, or a whole Float (15.0); nil for anything else, including numeric strings.
  def whole_number(value)
    return value if value.is_a?(Integer)
    value.to_i if value.is_a?(Float) && value == value.floor
  end
end
