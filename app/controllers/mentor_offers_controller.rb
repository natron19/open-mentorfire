class MentorOffersController < ApplicationController
  before_action :set_mentor_offer, only: %i[show edit update destroy]

  def index
    @mentor_offers = current_user.mentor_offers.includes(:latest_program_draft).order(created_at: :desc)
  end

  def show
    @program_drafts = @mentor_offer.program_drafts.order(created_at: :desc)
  end

  def new
    @mentor_offer = current_user.mentor_offers.build(sessions_count: 4, session_minutes: 60)
  end

  def create
    @mentor_offer = current_user.mentor_offers.build(mentor_offer_params)
    if @mentor_offer.save
      redirect_to @mentor_offer
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @mentor_offer.update(mentor_offer_params)
      redirect_to @mentor_offer
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @mentor_offer.destroy
    redirect_to mentor_offers_path
  end

  private

  def set_mentor_offer
    @mentor_offer = current_user.mentor_offers.find(params[:id])
  end

  def mentor_offer_params
    params.require(:mentor_offer).permit(:subject, :experience, :who_its_for, :sessions_count, :session_minutes)
  end
end
