defmodule EctoDeadlockTest do
  use ExUnit.Case, async: true
  doctest EctoDeadlock

  import Ecto.Query

  alias EctoDeadlock.Repo
  alias EctoDeadlock.Person

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "the truth" do
    {:ok, person} =
      %Person{first_name: "Tony", last_name: "Stark", age: 48}
      |> Repo.insert()

    parent = self()

    task = Task.async(fn ->
      Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

      Repo.transaction(fn ->
        IO.inspect "lock person"
        person = from(p in Person, where: p.id == ^person.id, lock: "FOR UPDATE") |> Repo.one()
        IO.inspect "person locked"

        send(parent, :select_person)

        receive do
          :quit ->
            IO.inspect "task received quit"
            {:ok, nil}
        end
      end)

      IO.inspect "transaction is over"
    end)

    receive do
      :select_person ->
        IO.inspect "trying to select person"
        person = from(p in Person, where: p.id == ^person.id, lock: "FOR UPDATE NOWAIT")
                  |> Repo.one()
        IO.inspect "person selected: #{inspect(person)}"

        assert is_nil(person)
    end

    send(task.pid, :quit)
    Task.shutdown(task, 1000)
  end

  test "the truth 2" do
    {:ok, person} =
      %Person{first_name: "Tony", last_name: "Stark", age: 48}
      |> Repo.insert()

    parent = self()

    task = Task.async(fn ->
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

      Repo.transaction(fn ->
        IO.inspect "lock person"
        person = from(p in Person, where: p.id == ^person.id, lock: "FOR UPDATE") |> Repo.one()
        IO.inspect "person locked"

        send(parent, :select_person)

        receive do
          :quit ->
            IO.inspect "task received quit"
            {:ok, nil}
        end
      end)

      IO.inspect "transaction is over"
    end)

    receive do
      :select_person ->
        IO.inspect "trying to select person"
        person = from(p in Person, where: p.id == ^person.id, lock: "FOR UPDATE NOWAIT")
                 |> Repo.one()
        IO.inspect "person selected: #{inspect(person)}"

        assert is_nil(person)
    end

    send(task.pid, :quit)
    Task.shutdown(task, 1000)
  end
end
