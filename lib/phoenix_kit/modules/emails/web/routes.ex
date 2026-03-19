defmodule PhoenixKit.Modules.Emails.Web.Routes do
  @moduledoc """
  Public route definitions for Emails module.
  Admin LiveView routes are auto-generated from live_view: fields in admin_tabs/0.
  """

  def generate(url_prefix) do
    webhook_controller = PhoenixKit.Modules.Emails.Web.WebhookController
    export_controller = PhoenixKit.Modules.Emails.Web.ExportController

    quote do
      scope unquote(url_prefix) do
        pipe_through([:browser])

        # Webhook (AWS SNS)
        post("/webhooks/ses", unquote(webhook_controller), :handle)

        # Email tracking
        get(
          "/emails/tracking/pixel/:id",
          unquote(PhoenixKit.Modules.Emails.Web.EmailTracking),
          :pixel
        )

        get(
          "/emails/tracking/link/:id",
          unquote(PhoenixKit.Modules.Emails.Web.EmailTracking),
          :link
        )

        # Export
        get("/emails/export/:format", unquote(export_controller), :export)
      end
    end
  end
end
