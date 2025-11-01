module Containers
  class OpenController < ApplicationController
    before_action :authenticate_user!
    helper InventoriesHelper

    def create
      result = Containers::ContainerOpener.call(
        user: current_user,
        chest_type_key: params[:chest_type_key],
        quantity: params[:quantity].presence || 1,
        request_uuid: params[:request_uuid],
        latency_ms: params[:latency_ms],
        client_version: params[:client_version]
      )

      @rewards_payload = {
        "opened" => result.opened,
        "chest_type" => result.chest_type,
        "rewards" => result.rewards,
        "remaining_count" => result.remaining_count,
        "request_uuid" => result.request_uuid
      }

      @containers = current_user.user_containers.includes(:chest_type).order("chest_types.min_level ASC")
      @container_lookup = @containers.each_with_object({}) do |record, memo|
        chest = record.chest_type
        memo[chest.key] = record if chest
      end
      @items = current_user.user_items.includes(:item).order("items.name ASC")
      @containers_total = @containers.sum(&:count)
      @items_total = @items.sum(&:quantity)
      @user_stats = current_user.user_stat || current_user.create_user_stat!(User::STAT_DEFAULTS.merge(energy_updated_at: Time.current))

      respond_to do |format|
        format.turbo_stream
        format.json { render json: @rewards_payload, status: :ok }
      end
    rescue Containers::ContainerOpener::InsufficientContainers => e
      respond_with_error(e.message, :unprocessable_entity)
    rescue Containers::ContainerOpener::BatchNotAllowed => e
      respond_with_error(e.message, :unprocessable_entity)
    rescue StandardError => e
      Rails.logger.error("[Containers::OpenController] #{e.class}: #{e.message}")
      respond_with_error("Unable to open container at this time.", :internal_server_error)
    end

    private

    def respond_with_error(message, status)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "container-open-errors",
            partial: "containers/open/error",
            locals: { message: message }
          )
        end
        format.json { render json: { error: message }, status: status }
      end
    end
  end
end
