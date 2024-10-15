from django.contrib import admin
from goods.models import Category, Service

# admin.site.register(Category)
# admin.site.register(Service)

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    prepopulated_fields = {'slug': ('category_name', )}

@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    prepopulated_fields = {'slug': ('service_name', )}