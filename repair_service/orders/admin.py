from django.contrib import admin
from goods.models import Service
from users.models import Employee
from .models import Order, OrderItem, Status


admin.site.register(Status)


class OrderItemTabulareAdmin(admin.TabularInline):
    model = OrderItem
    fields = ("product", "name", "price", "quantity", "status", "employee")
    extra = 0




@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = ("order", "product", "name", "price", "quantity", "status", "employee")
    search_fields = ("order", "product", "name")

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "employee":
            # Получаем текущий объект OrderItem, если он уже существует
            obj_id = request.resolver_match.kwargs.get('object_id')
            if obj_id:
                order_item = OrderItem.objects.get(pk=obj_id)
                # Устанавливаем фильтрацию сотрудников по категории услуги
                kwargs["queryset"] = Employee.objects.filter(category=order_item.product.category)
            else:
                # Если это новый объект, то по выбранной услуге
                product_id = request.POST.get('product')  # Получаем id выбранного продукта
                if product_id:
                    try:
                        product = Service.objects.get(id=product_id)
                        kwargs["queryset"] = Employee.objects.filter(category=product.category)
                    except Service.DoesNotExist:
                        kwargs["queryset"] = Employee.objects.none()

        return super().formfield_for_foreignkey(db_field, request, **kwargs)


class OrderTabulareAdmin(admin.TabularInline):
    model = Order
    fields = ("requires_delivery", "status", "payment_on_get", "is_paid", "created_timestamp",)
    search_fields = ("requires_delivery", "payment_on_get", "is_paid", "created_timestamp",)
    readonly_fields = ("created_timestamp",)
    extra = 0

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "status":
            kwargs["queryset"] = Status.objects.filter(status_category="Услуга")
        return super().formfield_for_foreignkey(db_field, request, **kwargs)


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "requires_delivery",
        "delivery_address",
        "delivery_date",
        "delivery_time",
        "status",
        "payment_on_get",
        "is_paid",
        "created_timestamp",
    )
    search_fields = ("id",)
    readonly_fields = ("created_timestamp",)
    list_filter = (
        "requires_delivery",
        "status",
        "payment_on_get",
        "is_paid",
        "delivery_date",
    )
    inlines = (OrderItemTabulareAdmin,)
