defmodule PhoenixKitEmails.IntegrationTest do
  use ExUnit.Case, async: false

  alias PhoenixKit.Modules.Emails.ApplicationIntegration
  alias PhoenixKit.Modules.Emails.Provider

  test "ApplicationIntegration.register sets unified provider" do
    Application.delete_env(:phoenix_kit, :email_provider)

    ApplicationIntegration.register()

    assert Application.get_env(:phoenix_kit, :email_provider) == Provider
  end
end
