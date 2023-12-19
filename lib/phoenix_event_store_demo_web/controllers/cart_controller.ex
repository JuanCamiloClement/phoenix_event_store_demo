defmodule PhoenixEventStoreDemoWeb.CartController do
  use PhoenixEventStoreDemoWeb, :controller
  use Spear.Client

  alias PhoenixEventStoreDemo.EventStoreDbClient

  def get_cart(conn, _params) do
    stream = EventStoreDbClient.stream!("CartForUser4")
    IO.inspect(build_cart_from_stream(stream))

    send_resp(conn, 200, "OK")
  end

  def create(conn, _params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser4")
    current_cart = build_cart_from_stream(stream)

    if current_cart == %{} do
      event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
      EventStoreDbClient.append([event], "CartForUser4")
      send_resp(conn, 200, "Cart created")
    else
      send_resp(conn, 200, "Cart is already created")
    end
  end

  def add_item(conn, %{"name" => name, "price" => _price, "amount" => _amount} = params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser4")
    current_cart = build_cart_from_stream(stream)

    if Enum.any?(current_cart["items"], fn list_element -> name == list_element["name"] end) do
      [repeated_product] =
        Enum.filter(current_cart["items"], fn list_element ->
          name == list_element["name"]
        end)

      new_product = %{
        "name" => repeated_product["name"],
        "price" => repeated_product["price"],
        "amount" => repeated_product["amount"] + 1
      }

      event = Spear.Event.new("ItemQuantityUpdated", new_product)
      EventStoreDbClient.append([event], "CartForUser4")
    else
      event = Spear.Event.new("ItemAdded", params)
      EventStoreDbClient.append([event], "CartForUser4")
    end

    send_resp(conn, 200, "OK")
  end

  def update_item_quantity(conn, %{"name" => name, "amount" => amount}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser4")
    current_cart = build_cart_from_stream(stream)

    [product_to_update] =
      Enum.filter(current_cart["items"], fn product -> product["name"] == name end)

    updated_product = %{
      "name" => product_to_update["name"],
      "price" => product_to_update["price"],
      "amount" => amount
    }

    if amount == 0 do
      event = Spear.Event.new("ItemRemoved", product_to_update["name"])
      EventStoreDbClient.append([event], "CartForUser4")
      send_resp(conn, 201, "Item removed from cart")
    else
      event = Spear.Event.new("ItemQuantityUpdated", updated_product)
      EventStoreDbClient.append([event], "CartForUser4")
      send_resp(conn, 200, "Item amount updated")
    end
  end

  def remove_item(conn, %{"name" => name}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser4")
    current_cart = build_cart_from_stream(stream)

    if !Enum.any?(current_cart["items"], fn product -> product["name"] == name end) do
      send_resp(conn, 406, "Item not in cart")
    else
      event = Spear.Event.new("ItemRemoved", name)
      EventStoreDbClient.append([event], "CartForUser4")
      send_resp(conn, 200, "Item removed from cart")
    end
  end

  def empty_cart(conn, _params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser4")
    current_cart = build_cart_from_stream(stream)

    if current_cart["items"] == [] do
      send_resp(conn, 200, "Cart is already empty")
    else
      event = Spear.Event.new("CartEmptied", %{})
      EventStoreDbClient.append([event], "CartForUser4")
      send_resp(conn, 200, "Cart emptied")
    end
  end

  def add_discount_coupon(conn, %{"coupon" => coupon}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser4")
    current_cart = build_cart_from_stream(stream)

    cond do
      current_cart["coupon"] == nil ->
        event = Spear.Event.new("CouponAdded", %{"percentage" => coupon})
        EventStoreDbClient.append([event], "CartForUser4")
        send_resp(conn, 200, "Coupon added")

      current_cart["coupon"]["percentage"] + coupon <= 100 ->
        event =
          Spear.Event.new("CouponAdded", %{
            "percentage" => current_cart["coupon"]["percentage"] + coupon
          })

        EventStoreDbClient.append([event], "CartForUser4")
        send_resp(conn, 200, "Coupon added")

      current_cart["coupon"]["percentage"] + coupon > 100 ->
        send_resp(conn, 200, "Cannot exceed discount of 100%")
    end
  end

  def remove_discount_coupon(conn, %{"coupon" => coupon}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser4")
    current_cart = build_cart_from_stream(stream)

    cond do
      current_cart["coupon"] == nil ->
        send_resp(conn, 200, "No coupon to be removed")

      current_cart["coupon"]["percentage"] - String.to_integer(coupon) < 0 ->
        send_resp(conn, 200, "Cannot have negative coupon value")

      current_cart["coupon"]["percentage"] - String.to_integer(coupon) > 0 ->
        event =
          Spear.Event.new("CouponRemoved", %{
            "percentage" => current_cart["coupon"]["percentage"] - String.to_integer(coupon)
          })

        EventStoreDbClient.append([event], "CartForUser4")
        send_resp(conn, 200, "Coupon removed")

      current_cart["coupon"]["percentage"] - String.to_integer(coupon) == 0 ->
        event = Spear.Event.new("CouponRemoved", nil)
        EventStoreDbClient.append([event], "CartForUser4")
        send_resp(conn, 200, "Coupon removed")
    end
  end

  def build_cart_from_stream(stream) do
    Enum.reduce(stream, %{}, fn current_event, acc ->
      case current_event.type do
        "CartCreated" ->
          current_event.body

        "ItemAdded" ->
          %{"items" => [current_event.body | acc["items"]], "coupon" => acc["coupon"]}

        "ItemQuantityUpdated" ->
          [product_to_delete] =
            Enum.filter(acc["items"], fn list_element ->
              current_event.body["name"] == list_element["name"]
            end)

          new_acc = List.delete(acc["items"], product_to_delete)
          %{"items" => [current_event.body | new_acc], "coupon" => acc["coupon"]}

        "ItemRemoved" ->
          [product_to_delete] =
            Enum.filter(acc["items"], fn list_element ->
              current_event.body == list_element["name"]
            end)

          %{"items" => List.delete(acc["items"], product_to_delete), "coupon" => acc["coupon"]}

        "CartEmptied" ->
          %{"items" => [], "coupon" => acc["coupon"]}

        "CouponAdded" ->
          %{"items" => acc["items"], "coupon" => current_event.body}

        "CouponRemoved" ->
          %{"items" => acc["items"], "coupon" => current_event.body}

        _ ->
          acc
      end
    end)
  end
end
