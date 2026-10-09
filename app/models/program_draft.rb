class ProgramDraft < ApplicationRecord
  belongs_to :mentor_offer
  has_one :user, through: :mentor_offer

  STATUSES  = %w[pending completed failed].freeze
  ASSIGNEES = %w[mentor mentee].freeze

  validates :status, inclusion: { in: STATUSES }

  def completed? = status == "completed"
  def failed?    = status == "failed"

  # The offer was edited after this draft ran.
  def stale?
    generated_at.present? && mentor_offer.updated_at > generated_at
  end

  # Tasks placed on a session (1..n), or at program level (0) when session is nil.
  def tasks_for(session_number)
    tasks.select { |t| t["session_number"].to_i == session_number.to_i }
  end

  def program_level_tasks = tasks_for(0)

  def agenda_minutes(session)
    Array(session["agenda"]).sum { |a| a["minutes"].to_i }
  end

  def to_markdown
    lines = []
    lines << "# #{name}"
    lines << ""
    lines << "_A mentoring Program drafted #{generated_at&.strftime('%Y-%m-%d') || 'on an unknown date'} by " \
             "#{ENV.fetch('APP_NAME', 'MentorFire Demo')} from the mentor's own experience. AI-generated: a first " \
             "draft for the mentor to edit, not a judgement of anyone._"
    lines << ""
    lines << "**Subject:** #{mentor_offer.subject}  "
    lines << "**Shape:** #{sessions_count} sessions of #{session_minutes} minutes"
    lines << ""
    lines << "## Purpose"
    lines << ""
    lines << purpose.to_s
    lines << ""
    lines << "> #{outcome_statement}"
    lines << ""
    lines << "## Sessions"
    sessions.each do |session|
      lines << ""
      lines << "### Session #{session['number']}: #{session['title']}"
      lines << ""
      lines << "_#{session['aim']}_"
      lines << ""
      session["agenda"].each { |a| lines << "- #{a['minutes']} min: #{a['item']}" }
      lines << ""
      lines << "Agenda total: #{agenda_minutes(session)} of #{session_minutes} minutes."
      session_tasks = tasks_for(session["number"])
      if session_tasks.any?
        lines << ""
        lines << "Tasks for this session:"
        session_tasks.each { |t| lines << "- [ ] #{t['name']} (#{t['assignee']})" }
      end
    end
    lines << ""
    if program_level_tasks.any?
      lines << "## Any time during the Program"
      lines << ""
      program_level_tasks.each { |t| lines << "- [ ] #{t['name']} (#{t['assignee']})" }
      lines << ""
    end
    lines << "## Three questions for the first intro"
    lines << ""
    first_intro_questions.each_with_index { |q, i| lines << "#{i + 1}. #{q}" }
    lines << ""
    lines << "## The offer"
    lines << ""
    lines << "_What I have actually done:_ #{mentor_offer.experience}"
    lines << ""
    lines << "_Who it is for:_ #{mentor_offer.who_its_for}"
    lines.join("\n") + "\n"
  end

  def markdown_filename
    slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "").presence || "program"
    "#{slug}-program.md"
  end
end
