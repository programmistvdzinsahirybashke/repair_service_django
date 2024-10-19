from django.contrib import admin
# from carts.admin import CartTabAdmin
# from orders.admin import OrderTabulareAdmin
from users.models import User
from orders.models import Order, OrderItem


admin.site.register(Order)
admin.site.register(OrderItem)