defmodule PhoenixEventStoreDemoWeb.CartController do
  use PhoenixEventStoreDemoWeb, :controller
  use Spear.Client

  alias PhoenixEventStoreDemo.EventStoreDbClient

  def calculate_cart_total(conn, _params) do
    stream = EventStoreDbClient.stream!("CartForUser7")
    IO.inspect(build_cart_from_stream(stream))

    send_resp(conn, 200, "OK")
  end

  def create(conn, _params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser7")
    current_cart = build_cart_from_stream(stream)

    if current_cart == %{} do
      event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
      EventStoreDbClient.append([event], "CartForUser7")
      send_resp(conn, 200, "Cart created")
    else
      send_resp(conn, 200, "Cart is already created")
    end
  end

  def add_item(conn, %{"name" => name, "price" => _price, "amount" => _amount} = params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser7")
    current_cart = build_cart_from_stream(stream)

    event =
      case Enum.find(current_cart["items"], &(&1["name"] == name)) do
        nil ->
          Spear.Event.new("ItemAdded", params)

        item ->
          Spear.Event.new("ItemQuantityIncreased", %{
            "name" => item["name"],
            "previousAmount" => item["amount"],
            "newAmount" => item["amount"] + 1
          })
      end

    EventStoreDbClient.append([event], "CartForUser7")

    send_resp(conn, 200, "OK")
  end

  def update_item_quantity(conn, %{"name" => name, "amount" => amount}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser7")
    current_cart = build_cart_from_stream(stream)

    item =
      Enum.find(current_cart["items"], &(&1["name"] == name))

    event =
      cond do
        amount == 0 ->
          Spear.Event.new("ItemRemoved", %{
            "name" => item["name"]
          })

        item["amount"] < amount ->
          Spear.Event.new("ItemQuantityIncreased", %{
            "name" => item["name"],
            "previousAmount" => item["amount"],
            "newAmount" => amount
          })

        item["amount"] > amount ->
          Spear.Event.new("ItemQuantityDecreased", %{
            "name" => item["name"],
            "previousAmount" => item["amount"],
            "newAmount" => amount
          })

        item["amount"] == amount ->
          nil
      end

    if event do
      EventStoreDbClient.append([event], "CartForUser7")
      send_resp(conn, 200, "Item amount updated")
    else
      send_resp(conn, 200, "Item amount is the same as saved amount")
    end
  end

  def remove_item(conn, %{"name" => name}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser7")
    current_cart = build_cart_from_stream(stream)

    if Enum.find(current_cart["items"], &(&1["name"] == name)) do
      event = Spear.Event.new("ItemRemoved", %{"name" => name})
      EventStoreDbClient.append([event], "CartForUser7")
      send_resp(conn, 200, "Item removed from cart")
    else
      send_resp(conn, 404, "Item not in cart")
    end
  end

  def empty_cart(conn, _params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser7")
    current_cart = build_cart_from_stream(stream)

    if current_cart["items"] == [] do
      send_resp(conn, 200, "Cart is already empty")
    else
      event = Spear.Event.new("CartEmptied", [])
      EventStoreDbClient.append([event], "CartForUser7")
      send_resp(conn, 200, "Cart emptied")
    end
  end

  def add_discount_coupon(conn, %{"coupon" => coupon}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser7")
    current_cart = build_cart_from_stream(stream)

    if !current_cart["coupon"] do
      event = Spear.Event.new("CouponAdded", %{"percentage" => coupon})
      EventStoreDbClient.append([event], "CartForUser7")
      send_resp(conn, 200, "Coupon added")
    else
      send_resp(conn, 200, "User already has an applied coupon")
    end
  end

  def remove_discount_coupon(conn, _params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser7")
    current_cart = build_cart_from_stream(stream)

    if current_cart["coupon"] do
      event = Spear.Event.new("CouponRemoved", %{"coupon" => current_cart["coupon"]})
      EventStoreDbClient.append([event], "CartForUser7")
      send_resp(conn, 200, "Coupon removed")
    else
      send_resp(conn, 200, "User has no coupon to be removed")
    end
  end

  def build_cart_from_stream(stream) do
    Enum.reduce(stream, %{}, fn current_event, acc ->
      case current_event.type do
        "CartCreated" ->
          current_event.body

        "ItemAdded" ->
          Map.put(acc, "items", [current_event.body | acc["items"]])

        "ItemQuantityIncreased" ->
          %{"price" => price} =
            Enum.find(acc["items"], &(&1["name"] == current_event.body["name"]))

          filtered_list =
            Enum.filter(acc["items"], &(&1["name"] != current_event.body["name"]))

          Map.put(acc, "items", [
            %{
              "name" => current_event.body["name"],
              "price" => price,
              "amount" => current_event.body["newAmount"]
            }
            | filtered_list
          ])

        "ItemQuantityDecreased" ->
          %{"price" => price} =
            Enum.find(acc["items"], &(&1["name"] == current_event.body["name"]))

          filtered_list =
            Enum.filter(acc["items"], &(&1["name"] != current_event.body["name"]))

          Map.put(acc, "items", [
            %{
              "name" => current_event.body["name"],
              "price" => price,
              "amount" => current_event.body["newAmount"]
            }
            | filtered_list
          ])

        "ItemRemoved" ->
          Map.put(
            acc,
            "items",
            Enum.filter(acc["items"], &(&1["name"] != current_event.body["name"]))
          )

        "CartEmptied" ->
          Map.put(acc, "items", [])

        "CouponAdded" ->
          Map.put(acc, "coupon", current_event.body)

        "CouponRemoved" ->
          Map.put(acc, "coupon", nil)

        _ ->
          acc
      end
    end)
  end
end
