# frozen_string_literal: true

class UserCalloutsController < ApplicationController
  feature_category :navigation

  def create
    if callout.persisted?
      respond_to do |format|
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.json { head :bad_request }
      end
    end
  end

  private

  def callout
    Users::DismissUserCalloutService.new(
      container: nil, current_user: current_user, params: { feature_name: feature_name }
    ).execute
  end

  def feature_name
    params.require(:feature_name)
  end
end
