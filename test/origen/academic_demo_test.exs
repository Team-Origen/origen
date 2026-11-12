defmodule Origen.AcademicDemoTest do
  # Reads and mutates OS environment variables and global application config.
  use ExUnit.Case, async: false

  alias Origen.AcademicDemo

  @env_var "ORIGEN_ACADEMIC_DEMO_PASSWORD_ONLY"

  setup do
    previous_env = System.get_env(@env_var)
    previous_config = Application.get_env(:origen, :academic_demo_password_only)

    on_exit(fn ->
      if previous_env,
        do: System.put_env(@env_var, previous_env),
        else: System.delete_env(@env_var)

      if is_nil(previous_config),
        do: Application.delete_env(:origen, :academic_demo_password_only),
        else: Application.put_env(:origen, :academic_demo_password_only, previous_config)
    end)

    :ok
  end

  describe "config/runtime.exs" do
    test "turns the academic demo on only when the variable is exactly \"true\"" do
      System.put_env(@env_var, "true")
      assert runtime_flag() == true
    end

    test "keeps the academic demo off when the variable is unset or has any other value" do
      System.delete_env(@env_var)
      assert runtime_flag() == false

      for value <- ["false", "TRUE", "1", "yes", ""] do
        System.put_env(@env_var, value)
        assert runtime_flag() == false, "expected #{inspect(value)} to keep the flag off"
      end
    end
  end

  describe "password_only?/0" do
    test "is true only for the boolean true" do
      Application.put_env(:origen, :academic_demo_password_only, true)
      assert AcademicDemo.password_only?()

      for value <- [false, "true", 1, nil] do
        Application.put_env(:origen, :academic_demo_password_only, value)
        refute AcademicDemo.password_only?()
      end

      Application.delete_env(:origen, :academic_demo_password_only)
      refute AcademicDemo.password_only?()
    end
  end

  defp runtime_flag do
    "config/runtime.exs"
    |> Config.Reader.read!(env: :test)
    |> get_in([:origen, :academic_demo_password_only])
  end
end
