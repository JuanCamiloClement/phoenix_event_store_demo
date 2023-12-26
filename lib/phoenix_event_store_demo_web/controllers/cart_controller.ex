defmodule PhoenixEventStoreDemoWeb.CartController do
  use PhoenixEventStoreDemoWeb, :controller
  use Spear.Client

  alias PhoenixEventStoreDemo.EventStoreDbClient
  alias PhoenixEventStoreDemo.ShoppingCart

  @spec print_cart(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def print_cart(conn, _params) do
    stream = EventStoreDbClient.stream!("CartForUser11")
    IO.inspect(ShoppingCart.build_cart_from_stream(stream))
    IO.inspect(ShoppingCart.calculate_cart_total(stream))

    send_resp(conn, 200, "OK")
  end

  def create(conn, _params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser11")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    event = ShoppingCart.create(current_cart)

    if event do
      EventStoreDbClient.append([event], "CartForUser11")
      send_resp(conn, 200, "Cart created")
    else
      send_resp(conn, 200, "Cart is already created")
    end
  end

  def add_item(conn, %{"name" => _name, "price" => _price, "amount" => _amount} = params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser11")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    event = ShoppingCart.add_item(current_cart, params)

    EventStoreDbClient.append([event], "CartForUser11")

    send_resp(conn, 200, "OK")
  end

  def update_item_quantity(conn, %{"name" => _name, "amount" => _amount} = params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser11")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    event = ShoppingCart.update_item_quantity(current_cart, params)

    if event do
      EventStoreDbClient.append([event], "CartForUser11")
      send_resp(conn, 200, "Item amount updated")
    else
      send_resp(conn, 200, "Item amount is the same as saved amount")
    end
  end

  def remove_item(conn, %{"name" => name}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser11")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    event = ShoppingCart.remove_item(current_cart, name)

    if event do
      EventStoreDbClient.append([event], "CartForUser11")
      send_resp(conn, 200, "Item removed from cart")
    else
      send_resp(conn, 404, "Item not in cart")
    end
  end

  def empty_cart(conn, _params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser11")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    event = ShoppingCart.empty_cart(current_cart)

    if event do
      EventStoreDbClient.append([event], "CartForUser11")
      send_resp(conn, 200, "Cart emptied")
    else
      send_resp(conn, 200, "Cart is already empty")
    end
  end

  def add_discount_coupon(conn, %{"coupon" => coupon}) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser11")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    event = ShoppingCart.add_discount_coupon(current_cart, coupon)

    if event do
      EventStoreDbClient.append([event], "CartForUser11")
      send_resp(conn, 200, "Coupon added")
    else
      send_resp(conn, 200, "User already has an applied coupon")
    end
  end

  def remove_discount_coupon(conn, _params) do
    # Get current cart
    stream = EventStoreDbClient.stream!("CartForUser11")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    event = ShoppingCart.remove_discount_coupon(current_cart)

    if event do
      EventStoreDbClient.append([event], "CartForUser11")
      send_resp(conn, 200, "Coupon removed")
    else
      send_resp(conn, 200, "User has no coupon to be removed")
    end
  end
end
