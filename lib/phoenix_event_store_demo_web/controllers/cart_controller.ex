defmodule PhoenixEventStoreDemoWeb.CartController do
  use PhoenixEventStoreDemoWeb, :controller
  use Spear.Client

  alias PhoenixEventStoreDemo.EventStoreDbClient

  def get_cart(conn, _params) do
    stream = EventStoreDbClient.stream!("CartForUser12345")
    IO.inspect(build_cart_from_stream(stream))

    send_resp(conn, 200, "OK")
  end

  def create(conn, _params) do
    event = Spear.Event.new("CartCreated", %{})
    EventStoreDbClient.append([event], "CartForUser12345")
    send_resp(conn, 200, "OK")
  end

  def add_item(conn, %{"name" => name, "price" => _price, "amount" => _amount} = params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser12345")
    current_cart = build_cart_from_stream(stream)

    if Enum.any?(current_cart, fn list_element -> name == list_element["name"] end) do
      [repeated_product] =
        Enum.filter(current_cart, fn list_element ->
          name == list_element["name"]
        end)

      new_product = %{
        "name" => repeated_product["name"],
        "price" => repeated_product["price"],
        "amount" => repeated_product["amount"] + 1
      }

      event = Spear.Event.new("ItemQuantityUpdated", new_product)
      EventStoreDbClient.append([event], "CartForUser12345")
    else
      event = Spear.Event.new("ItemAdded", params)
      EventStoreDbClient.append([event], "CartForUser12345")
    end

    send_resp(conn, 200, "OK")
  end

  def update_item_quantity(conn, %{"name" => name, "amount" => amount}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser12345")
    current_cart = build_cart_from_stream(stream)

    [product_to_update] = Enum.filter(current_cart, fn product -> product["name"] == name end)

    updated_product = %{
      "name" => product_to_update["name"],
      "price" => product_to_update["price"],
      "amount" => amount
    }

    if amount == 0 do
      event = Spear.Event.new("ItemRemoved", product_to_update["name"])
      EventStoreDbClient.append([event], "CartForUser12345")
      send_resp(conn, 201, "Item removed from cart")
    else
      event = Spear.Event.new("ItemQuantityUpdated", updated_product)
      EventStoreDbClient.append([event], "CartForUser12345")
      send_resp(conn, 200, "Item amount updated")
    end
  end

  def remove_item(conn, %{"name" => name}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser12345")
    current_cart = build_cart_from_stream(stream)

    if !Enum.any?(current_cart, fn product -> product["name"] == name end) do
      send_resp(conn, 406, "Item not in cart")
    else
      event = Spear.Event.new("ItemRemoved", name)
      EventStoreDbClient.append([event], "CartForUser12345")
      send_resp(conn, 200, "Item removed from cart")
    end
  end

  def empty_cart(conn, _params) do
    event = Spear.Event.new("CartEmptied", %{})
    EventStoreDbClient.append([event], "CartForUser12345")
    send_resp(conn, 200, "Cart emptied")
  end

  def build_cart_from_stream(stream) do
    Enum.reduce(stream, [], fn current_event, acc ->
      case current_event.type do
        "ItemAdded" ->
          [current_event.body | acc]

        "ItemQuantityUpdated" ->
          [product_to_delete] =
            Enum.filter(acc, fn list_element ->
              current_event.body["name"] == list_element["name"]
            end)

          new_acc = List.delete(acc, product_to_delete)
          [current_event.body | new_acc]

        "ItemRemoved" ->
          [product_to_delete] =
            Enum.filter(acc, fn list_element ->
              current_event.body == list_element["name"]
            end)

          List.delete(acc, product_to_delete)

        "CartEmptied" ->
          []

        _ ->
          acc
      end
    end)
  end
end
