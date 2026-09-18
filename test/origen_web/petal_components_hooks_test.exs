defmodule OrigenWeb.PetalComponentsHooksTest do
  use ExUnit.Case, async: true

  @app_js Path.expand("../../assets/js/app.js", __DIR__)

  test "registers the official Petal hooks without replacing colocated hooks" do
    source = File.read!(@app_js)

    assert source =~
             ~s(import PetalComponents from "../../deps/petal_components/assets/js/petal_components")

    assert source =~
             ~r/hooks:\s*\{\s*\.\.\.PetalComponents,\s*\.\.\.colocatedHooks\s*\}/
  end
end
