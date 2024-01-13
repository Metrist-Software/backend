defmodule Domain.StatusPageTest do
  use ExUnit.Case, async: true

  alias Commanded.Aggregate.Multi
  alias Domain.StatusPage.Commands
  alias Domain.StatusPage.Events

  describe "scraping statuspage.io status page(s)" do
    test "page components with the same name get a unique key in the aggregate state(s)" do
      page = %Domain.StatusPage{id: "zoom"}

      cmd = %Commands.ProcessObservations{
        id: "zoom",
        observations: [
          %Domain.StatusPage.Commands.Observation{
            changed_at: ~N[2022-08-09 20:58:25.957679],
            component: "Zoom Meetings",
            data_component_id: "6np407v7v25g",
            instance: "us-east-1",
            state: :up,
            status: "operational"
          },
          %Domain.StatusPage.Commands.Observation{
            changed_at: ~N[2022-08-09 20:58:25.957703],
            component: "Zoom Meetings",
            data_component_id: "3z7b6jks10hm",
            instance: "us-east-1",
            state: :up,
            status: "operational"
          }
        ]
      }

      {page, _events} = Domain.StatusPage.execute(page, cmd) |> Multi.run()

      assert %Domain.StatusPage{
               components: %{
                 {"Zoom Meetings", "us-east-1", "3z7b6jks10hm"} => [
                   "operational",
                   ~N[2022-08-09 20:58:25.957703],
                   _id1
                 ],
                 {"Zoom Meetings", "us-east-1", "6np407v7v25g"} => [
                   "operational",
                   ~N[2022-08-09 20:58:25.957679],
                   _id2
                 ]
               },
               id: "zoom",
               scraped_components: %{
                 {"Zoom Meetings", "us-east-1", "3z7b6jks10hm"} => _id3,
                 {"Zoom Meetings", "us-east-1", "6np407v7v25g"} => _id4
               },
               x_val: nil
             } = page
    end
  end

  describe "applying Commands.ProcessObservations" do
    test "when there are no observations (empty scrape result), components and scraped_components in aggregate state is empty" do
      # associated subscriptions are removed via an event handler...
      cmd = %Commands.ProcessObservations{
        id: "status_page_1",
        observations: []
      }

      page = %Domain.StatusPage{
        id: "status_page_1",
        components: %{
          {"component_name_1", "us-east-1", "data_component_id1"} => [
            "up",
            ~N[2022-08-14 00:02:57.043960],
            "11yfYK8z2IdpDpFrLLbXOgw"
          ],
          {"component_name_2", "us-east-1", "data_component_id2"} => [
            "up",
            ~N[2022-08-14 00:02:57.043960],
            "11yfYK8z2MwmHHIHkpLAyJL"
          ]
        },
        scraped_components: %{
          {"component_name_1", "us-east-1", "data_component_id1"} =>
            "component_name_1-us-east-1-data_component_id1",
          {"component_name_2", "us-east-1", "data_component_id2"} =>
            "component_name_2-us-east-1-data_component_id2"
        },
        subscriptions: [
          %Domain.StatusPage.Subscription{
            id: "subscription_id1",
            component_id: "component_name_1-us-east-1-data_component_id1",
            account_id: "accountid_1"
          },
          %Domain.StatusPage.Subscription{
            id: "subscription_id2",
            component_id: "component_name_2-us-east-1-data_component_id2",
            account_id: "accountid_2"
          }
        ],
        x_val: nil
      }

      {page, events} = Domain.StatusPage.execute(page, cmd) |> Multi.run()

      assert page == %Domain.StatusPage{
               components: %{},
               id: "status_page_1",
               scraped_components: %{},
               subscriptions: [
                 %Domain.StatusPage.Subscription{
                   account_id: "accountid_1",
                   component_id: "component_name_1-us-east-1-data_component_id1",
                   id: "subscription_id1"
                 },
                 %Domain.StatusPage.Subscription{
                   account_id: "accountid_2",
                   component_id: "component_name_2-us-east-1-data_component_id2",
                   id: "subscription_id2"
                 }
               ],
               x_val: nil
             }

      assert events == [
               %Domain.StatusPage.Events.ComponentRemoved{
                 account_id: "SHARED",
                 component_id: "component_name_1-us-east-1-data_component_id1",
                 data_component_id: "data_component_id1",
                 id: "status_page_1",
                 instance: "us-east-1",
                 name: "component_name_1"
               },
               %Domain.StatusPage.Events.ComponentRemoved{
                 account_id: "SHARED",
                 component_id: "component_name_2-us-east-1-data_component_id2",
                 data_component_id: "data_component_id2",
                 id: "status_page_1",
                 instance: "us-east-1",
                 name: "component_name_2"
               }
             ]

    end
  end

  describe "build_component_id/1" do
    test "with data_component_id builds hyphenated key" do
      assert Domain.StatusPage.build_component_id(%{
               name: "npm_test",
               instance: "us-east-1",
               data_component_id: "6np407v7v25g"
             }) == "npm_test-us-east-1-6np407v7v25g"
    end

    test "with empty data_component_id builds hyphenated key with only instance and name" do
      assert Domain.StatusPage.build_component_id(%{
               name: "npm_test",
               instance: "us-east-1",
               data_component_id: nil
             }) == "npm_test-us-east-1"

      assert Domain.StatusPage.build_component_id(%{
               name: "npm_test",
               instance: "us-east-1",
               data_component_id: ""
             }) == "npm_test-us-east-1"
    end

    test "build_component_id/1 with nil will generate -nil- to match get_component_key" do

      component_id = Domain.StatusPage.build_component_id(
        %{
          instance: nil,
          name: "component",
          data_component_id: "data-id"
        }
      )

      assert component_id == "component-nil-data-id"
    end
  end

  describe "component_id_of/1" do
    test "when requested field (component_id) is nil, return :id value" do
      events = [
        %Events.ComponentAdded{
          account_id: "SHARED",
          change_id: "change123",
          instance: "us-east-1",
          id: "npm_test",
          name: "www.npmjs.com website",
          component_id: nil
        },
        %Domain.StatusPage.Events.ComponentRemoved{
          account_id: "SHARED",
          component_id: nil,
          data_component_id: "ghjvqll59f1x",
          id: "npm_test",
          instance: nil,
          name: "Enterprise"
        },
        %Events.ComponentStatusChanged{
          id: "testpage",
          change_id: Domain.Id.new(),
          component: "testcomponent",
          status: "up",
          state: :up,
          instance: "mars-north-1",
          changed_at: NaiveDateTime.utc_now(),
          component_id: nil
        }
      ]

      assert Enum.map(events, &Domain.StatusPage.component_id_of/1) == [
               "npm_test",
               "npm_test",
               "testpage"
             ]
    end

    test "when requested field (component_id) exists, return field value" do
      events = [
        %Events.ComponentAdded{
          account_id: "SHARED",
          change_id: "change123",
          instance: "us-east-1",
          id: "npm_test",
          data_component_id: "uhjvqll59f1u",
          name: "www.npmjs.com website",
          component_id: "www.npmjs.com website-us-east-1-uhjvqll59f1u"
        },
        %Domain.StatusPage.Events.ComponentRemoved{
          account_id: "SHARED",
          data_component_id: "ghjvqll59f1x",
          id: "npm_test",
          instance: "us-east-1",
          name: "Enterprise",
          component_id: "Enterprise-us-east-1-ghjvqll59f1x"
        },
        %Events.ComponentStatusChanged{
          id: "testpage",
          change_id: Domain.Id.new(),
          component: "testcomponent",
          status: "up",
          state: :up,
          instance: "mars-north-1",
          component_id: "testcomponent-mars-north-1",
          changed_at: NaiveDateTime.utc_now()
        }
      ]

      assert Enum.map(events, &Domain.StatusPage.component_id_of/1) == [
               "www.npmjs.com website-us-east-1-uhjvqll59f1u",
               "Enterprise-us-east-1-ghjvqll59f1x",
               "testcomponent-mars-north-1"
             ]
    end
  end

  test "New status observation changes status" do
    page = %Domain.StatusPage{id: "testpage"}

    cmd = %Commands.ProcessObservations{
      id: "testpage",
      observations: [
        %Commands.Observation{
          component: "testcomponent",
          status: "up",
          state: :up,
          changed_at: NaiveDateTime.utc_now(),
          instance: "mars-north-1"
        }
      ]
    }

    {_page, [%Events.ComponentStatusChanged{}, %Events.ComponentAdded{}] = events} =
      Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert length(events) == 2
  end

  test "Two same observations don't change status" do
    page =
      %Domain.StatusPage{id: "testpage"}
      |> Domain.StatusPage.apply(%Events.ComponentStatusChanged{
        id: "testpage",
        change_id: Domain.Id.new(),
        component: "testcomponent",
        status: "up",
        state: :up,
        instance: "mars-north-1",
        changed_at: NaiveDateTime.utc_now()
      })

    cmd = %Commands.ProcessObservations{
      id: "testpage",
      observations: [
        %Commands.Observation{
          component: "testcomponent",
          status: "up",
          state: :up,
          changed_at: NaiveDateTime.utc_now(),
          instance: "mars-north-1"
        }
      ]
    }

    {_page, [%Events.ComponentAdded{}] = events} =
      Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert length(events) == 1
  end

  test "Two different observations do change status" do
    page =
      %Domain.StatusPage{id: "testpage"}
      |> Domain.StatusPage.apply(%Events.ComponentStatusChanged{
        id: "testpage",
        change_id: Domain.Id.new(),
        component: "testcomponent",
        status: "left",
        state: :up,
        instance: "mars-north-1",
        changed_at: NaiveDateTime.utc_now()
      })

    cmd = %Commands.ProcessObservations{
      id: "testpage",
      observations: [
        %Commands.Observation{
          component: "testcomponent",
          status: "right",
          state: :up,
          changed_at: NaiveDateTime.utc_now(),
          instance: "mars-north-1"
        }
      ]
    }

    {_page, [%Events.ComponentStatusChanged{}, %Events.ComponentAdded{}] = events} =
      Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert length(events) == 2
  end

  test "For idempotecy, events older than last status change are rejected" do
    page =
      %Domain.StatusPage{id: "testpage"}
      |> Domain.StatusPage.apply(%Events.ComponentStatusChanged{
        id: "testpage",
        change_id: Domain.Id.new(),
        component: "testcomponent",
        status: "charm",
        state: :up,
        instance: "mars-north-1",
        changed_at: ~N[2021-10-09 08:07:06.543]
      })

    make_cmd = fn dt ->
      %Commands.ProcessObservations{
        id: "testpage",
        observations: [
          %Commands.Observation{
            component: "testcomponent",
            status: "stranghe",
            state: :up,
            changed_at: dt,
            instance: "mars-north-1"
          }
        ]
      }
    end

    cmd = make_cmd.(~N[2021-10-09 08:07:00.000])

    {_page, [%Events.ComponentAdded{}] = events} =
      Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert length(events) == 1

    cmd = make_cmd.(~N[2021-10-09 08:07:06.543])

    {_page, [%Events.ComponentAdded{}] = events} =
      Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert length(events) == 1

    cmd = make_cmd.(~N[2021-10-09 08:07:06.555])

    {_page, [%Events.ComponentStatusChanged{}, %Events.ComponentAdded{}] = events} =
      Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert length(events) == 2
  end

  test "For a previous status page component in unhealthy state that no longer part of the (scraped) observations, reset to up state" do
    instance = "us-east-1"

    page = %Domain.StatusPage{
      id: "npm_test",
      components: %{
        {"www.npmjs.com website", instance, "8mzc4ncc0r6m"} => [
          "operational",
          ~N[2021-10-09 08:07:06.543],
          "id1"
        ],
        {"npm Enterprise", instance, "4nj1xcbwf28g"} => [
          "major_outage",
          ~N[2021-10-09 08:07:06.543],
          "id2"
        ]
      }
    }

    cmd = %Commands.ProcessObservations{
      id: page.id,
      observations: [
        %Commands.Observation{
          data_component_id: "8mzc4ncc0r6m",
          component: "www.npmjs.com website",
          status: "operational",
          state: :up,
          changed_at: NaiveDateTime.utc_now(),
          instance: "us-east-1"
        }
      ]
    }

    {_page,
     [
       %Domain.StatusPage.Events.ComponentStatusChanged{
         component: component,
         state: state,
         status: status
       },
       %Events.ComponentAdded{
         account_id: "SHARED",
         change_id: _,
         instance: "us-east-1",
         id: "npm_test",
         name: "www.npmjs.com website"
       }
     ] = events} = Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert [^component, ^state, ^status] = ["npm Enterprise", :up, "up"]
    assert length(events) == 2
  end

  test "Missing component that has already been reset should not continue emitting events" do
    page = %Domain.StatusPage{
      id: "npm_test",
      components: %{
        {"Enterprise", "us-east-1", "fvjvqll59f1x"} => [
          "operational",
          ~N[2021-10-09 08:07:06.543],
          "id1"
        ]
      }
    }

    cmd = %Commands.ProcessObservations{
      id: page.id,
      observations: [
        %Commands.Observation{
          data_component_id: "fvjvqll59f1x",
          component: "www.npmjs.com website",
          status: "operational",
          state: :up,
          changed_at: NaiveDateTime.utc_now(),
          instance: "us-east-1"
        },
        %Commands.Observation{
          data_component_id: "ghjvqll59f1x",
          component: "Enterprise",
          status: "major_outage",
          state: :down,
          changed_at: NaiveDateTime.utc_now(),
          instance: "us-east-1"
        }
      ]
    }

    {page, _events} = Domain.StatusPage.execute(page, cmd) |> Multi.run()

    cmd = %Commands.ProcessObservations{
      id: page.id,
      observations: [
        %Commands.Observation{
          data_component_id: "fvjvqll59f1x",
          component: "www.npmjs.com website",
          status: "operational",
          state: :up,
          changed_at: NaiveDateTime.utc_now(),
          instance: "us-east-1"
        }
      ]
    }

    {_page, [%Events.ComponentStatusChanged{}, %Events.ComponentRemoved{}] = events} =
      Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert length(events) == 2

    cmd = %Commands.ProcessObservations{
      id: page.id,
      observations: [
        %Commands.Observation{
          data_component_id: "fvjvqll59f1x",
          component: "www.npmjs.com website",
          status: "operational",
          state: :up,
          changed_at: NaiveDateTime.utc_now(),
          instance: "us-east-1"
        }
      ]
    }

    {_page, [%Events.ComponentStatusChanged{}, %Events.ComponentRemoved{}] = events} =
      Domain.StatusPage.execute(page, cmd) |> Multi.run()

    assert length(events) == 2
  end

  test "Can't process commands without a create" do
    user = %Domain.StatusPage{}

    cmd = %Domain.StatusPage.Commands.Print{id: "42"}

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:error, :no_create_command_seen} == Domain.StatusPage.execute(user, cmd)
    end)
  end

  test "Applying ComponentAdded updates aggregate state" do
    status_page =
      %Domain.StatusPage{
        id: "status_page_1",
        scraped_components: %{
          {"component_name_1", "us-east-1", "data_component_id1"} =>
            "component_name_1-us-east-1-data_component_id1",
          {"component_name_2", "us-east-1", "data_component_id2"} =>
            "component_name_2-us-east-1-data_component_id2"
        },
        components: %{
          {"component_name_1", "us-east-1", "data_component_id1"} => [
            "up",
            ~N[2022-08-14 00:02:57.043960],
            "11yfYK8z2IdpDpFrLLbXOgw"
          ],
          {"component_name_2", "us-east-1", "data_component_id2"} => [
            "up",
            ~N[2022-08-14 00:02:57.043960],
            "11yfYK8z2MwmHHIHkpLAyJL"
          ]
        },
        subscriptions: []
      }
      |> Domain.StatusPage.apply(%Events.ComponentAdded{
        account_id: "SHARED",
        data_component_id: "data_component_id3",
        change_id: "change123",
        instance: "us-east-1",
        id: "component3",
        name: "component_name_3",
        component_id: "component_name_3-us-east-1_data_component_id3"
      })
      |> Domain.StatusPage.apply(%Events.ComponentAdded{
        account_id: "SHARED",
        change_id: "change123",
        instance: "us-east-1",
        id: "component4",
        name: "component_name_4",
        component_id: "component_name_4-us-east-1"
      })

    assert status_page == %Domain.StatusPage{
             components: %{
               {"component_name_1", "us-east-1", "data_component_id1"} => [
                 "up",
                 ~N[2022-08-14 00:02:57.043960],
                 "11yfYK8z2IdpDpFrLLbXOgw"
               ],
               {"component_name_2", "us-east-1", "data_component_id2"} => [
                 "up",
                 ~N[2022-08-14 00:02:57.043960],
                 "11yfYK8z2MwmHHIHkpLAyJL"
               ]
             },
             id: "status_page_1",
             scraped_components: %{
               {"component_name_1", "us-east-1", "data_component_id1"} =>
                 "component_name_1-us-east-1-data_component_id1",
               {"component_name_2", "us-east-1", "data_component_id2"} =>
                 "component_name_2-us-east-1-data_component_id2",
               {"component_name_3", "us-east-1", "data_component_id3"} =>
                 "component_name_3-us-east-1_data_component_id3",
               {"component_name_4", "us-east-1", nil} => "component_name_4-us-east-1"
             },
             subscriptions: [],
             x_val: nil
           }
  end

  test "Applying ComponentRemoved updates aggregate state" do
    status_page =
      %Domain.StatusPage{
        id: "status_page_1",
        scraped_components: %{
          {"component_name_1", "us-east-1", "data_component_id1"} =>
            "component_name_1-us-east-1-data_component_id1",
          {"component_name_2", "us-east-1", "data_component_id2"} =>
            "component_name_2-us-east-1-data_component_id2"
        },
        components: %{
          {"component_name_1", "us-east-1", "data_component_id1"} => [
            "up",
            ~N[2022-08-14 00:02:57.043960],
            "11yfYK8z2IdpDpFrLLbXOgw"
          ],
          {"component_name_2", "us-east-1", "data_component_id2"} => [
            "up",
            ~N[2022-08-14 00:02:57.043960],
            "11yfYK8z2MwmHHIHkpLAyJL"
          ]
        },
        subscriptions: []
      }
      |> Domain.StatusPage.apply(%Events.ComponentRemoved{
        account_id: "SHARED",
        component_id: "component_name_1-us-east-1-data_component_id1",
        data_component_id: "data_component_id1",
        id: "component1",
        instance: "us-east-1",
        name: "component_name_1"
      })

    assert status_page == %Domain.StatusPage{
             components: %{
               {"component_name_2", "us-east-1", "data_component_id2"} => [
                 "up",
                 ~N[2022-08-14 00:02:57.043960],
                 "11yfYK8z2MwmHHIHkpLAyJL"
               ]
             },
             id: "status_page_1",
             scraped_components: %{
               {"component_name_2", "us-east-1", "data_component_id2"} =>
                 "component_name_2-us-east-1-data_component_id2"
             },
             subscriptions: [],
             x_val: nil
           }
  end

  test "Applying SubscriptionAdded updates aggregate state" do
    subscription_id = Domain.Id.new()

    sp =
      %Domain.StatusPage{
        id: "status_page_1",
        scraped_components: %{
          {"component_name_1", "us-east-1", "data_component_id1"} => "component_id",
          {"component_name_2", "us-east-1", "data_component_id2"} => "component_id2"
        },
        components: %{},
        subscriptions: []
      }
      |> Domain.StatusPage.apply(%Events.SubscriptionAdded{
        id: "status_page_1",
        subscription_id: subscription_id,
        component_id: "component_id",
        account_id: "account_id"
      })

    assert length(sp.subscriptions) == 1
    assert Enum.at(sp.subscriptions, 0).id == subscription_id
    assert Enum.at(sp.subscriptions, 0).component_id == "component_id"
    assert Enum.at(sp.subscriptions, 0).account_id == "account_id"
  end

  test "Applying SubscriptionRemoved updates aggregate state" do
    subscription_id = Domain.Id.new()

    sp =
      %Domain.StatusPage{
        id: "status_page_1",
        scraped_components: %{
          {"component_name_1", "us-east-1", "data_component_id1"} => "component_id",
          {"component_name_2", "us-east-1", "data_component_id2"} => "component_id2"
        },
        components: %{},
        subscriptions: [
          %Domain.StatusPage.Subscription{
            id: subscription_id,
            component_id: "component_id",
            account_id: "account_id"
          },
          %Domain.StatusPage.Subscription{
            id: Domain.Id.new(),
            component_id: "component_id3",
            account_id: "account_id"
          }
        ]
      }
      |> Domain.StatusPage.apply(%Events.SubscriptionRemoved{
        id: "status_page_1",
        subscription_id: subscription_id,
        component_id: "component_id",
        account_id: "account_id"
      })

    assert length(sp.subscriptions) == 1
    assert Enum.at(sp.subscriptions, 0).component_id == "component_id3"
  end

  test "Reset command should issue events to cleanup projections" do
    sp = %Domain.StatusPage{
      id: "status_page_1",
      subscriptions: [
        %Domain.StatusPage.Subscription{
          id: "subscription_id",
          component_id: "component_1",
          account_id: "accountid_1"
        }
      ],
      scraped_components: %{
        {"component_name_1", "us-east-1", ""} => "component_id",
        {"component_name_2", "us-east-1", "component_2"} => "component_id2"
      },
      components: %{}
    }

    cmd = %Domain.StatusPage.Commands.Reset{
      id: "status_page_1"
    }

    {_status_page, events} =
      Domain.StatusPage.execute(sp, cmd)
      |> Commanded.Aggregate.Multi.run()

    # SubscriptionRemoved events are fired from the event_handler.ex
    assert length(
             Enum.filter(events, fn
               %Events.SubscriptionRemoved{} -> true
               _ -> false
             end)
           ) == 0

    assert length(
             Enum.filter(events, fn
               %Events.ComponentRemoved{} -> true
               _ -> false
             end)
           ) == 2
  end

  test "Applying SetSubscriptions updates aggregate state" do
    status_page = %Domain.StatusPage{
      id: "status_page_1",
      subscriptions: [
        %Domain.StatusPage.Subscription{
          id: "subscription_id1",
          component_id: "component_1",
          account_id: "accountid_1"
        },
        %Domain.StatusPage.Subscription{
          id: "subscription_id2",
          component_id: "component_2",
          account_id: "accountid_1"
        },
        %Domain.StatusPage.Subscription{
          id: "subscription_id3",
          component_id: "component_3",
          account_id: "accountid_1"
        },
        %Domain.StatusPage.Subscription{
          id: "subscription_id4",
          component_id: "component_4",
          account_id: "accountid_1"
        }
      ],
      scraped_components: %{},
      components: %{}
    }

    cmd = %Domain.StatusPage.Commands.SetSubscriptions{
      component_ids: ["component_1", "component_4", "component_5", "component_6"],
      account_id: "accountid_1",
      id: "status_page_1"
    }

    {_status_page, events} = Domain.StatusPage.execute(status_page, cmd)
      |> Commanded.Aggregate.Multi.run()

    assert length(
      Enum.filter(events, fn
        %Events.SubscriptionRemoved{} -> true
        _ -> false
      end)
    ) == 2
    assert length(
      Enum.filter(events, fn
        %Events.SubscriptionAdded{} -> true
        _ -> false
      end)
    ) == 2
  end

  test "Applying SetSubscriptions only looks at subscriptions for account" do
    status_page = %Domain.StatusPage{
      id: "status_page_1",
      subscriptions: [
        %Domain.StatusPage.Subscription{
          id: "subscription_id1",
          component_id: "component_1",
          account_id: "accountid_1"
        },
        %Domain.StatusPage.Subscription{
          id: "subscription_id2",
          component_id: "component_2",
          account_id: "accountid_1"
        },
        %Domain.StatusPage.Subscription{
          id: "subscription_id3",
          component_id: "component_3",
          account_id: "accountid_2"
        },
        %Domain.StatusPage.Subscription{
          id: "subscription_id4",
          component_id: "component_4",
          account_id: "accountid_2"
        }
      ],
      scraped_components: %{},
      components: %{}
    }

    cmd = %Domain.StatusPage.Commands.SetSubscriptions{
      component_ids: ["component_1", "component_4", "component_5", "component_6"],
      account_id: "accountid_1",
      id: "status_page_1"
    }

    {_status_page, events} = Domain.StatusPage.execute(status_page, cmd)
      |> Commanded.Aggregate.Multi.run()

    assert length(
      Enum.filter(events, fn
        %Events.SubscriptionRemoved{} -> true
        _ -> false
      end)
    ) == 1
    assert length(
      Enum.filter(events, fn
        %Events.SubscriptionAdded{} -> true
        _ -> false
      end)
    ) == 3
  end
end
