class MentorOffer < ApplicationRecord
  belongs_to :user
  has_many :program_drafts, dependent: :destroy
  has_one :latest_program_draft,
          -> { order(generated_at: :desc, created_at: :desc) },
          class_name: "ProgramDraft"

  SESSION_COUNTS  = (3..8).to_a.freeze
  SESSION_LENGTHS = [ 30, 45, 60, 90 ].freeze

  validates :subject,         presence: true, length: { in: 3..120 }
  validates :experience,      presence: true, length: { in: 40..2500 }
  validates :who_its_for,     presence: true, length: { in: 10..600 }
  validates :sessions_count,  presence: true, inclusion: { in: SESSION_COUNTS, message: "must be between 3 and 8" }
  validates :session_minutes, presence: true, inclusion: { in: SESSION_LENGTHS, message: "must be 30, 45, 60 or 90" }

  # "4 sessions of 60 minutes"
  def shape_label
    "#{sessions_count} sessions of #{session_minutes} minutes"
  end

  # Variables for the mentorfire_program_v1 template. Nothing about the mentor's account (name, email) is sent.
  def ai_variables
    {
      subject:         subject,
      experience:      experience,
      who_its_for:     who_its_for,
      sessions_count:  sessions_count.to_s,
      session_minutes: session_minutes.to_s
    }
  end
end
