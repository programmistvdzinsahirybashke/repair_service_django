from django.contrib import admin

from carts.admin import CartTabAdmin
from users.models import User

# admin.site.register(Category)
# admin.site.register(Service)

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ['id', 'first_name', 'last_name', 'email' ]

    inlines = [CartTabAdmin,]