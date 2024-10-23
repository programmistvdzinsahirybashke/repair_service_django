from django.contrib import admin

from carts.admin import CartTabAdmin
from users.models import User, Employee
from orders.admin import OrderTabulareAdmin


# admin.site.register(Category)
admin.site.register(Employee)

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ['id', 'first_name', 'last_name', 'email' ]

    inlines = [CartTabAdmin, OrderTabulareAdmin]