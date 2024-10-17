from django.contrib.admin.templatetags.admin_list import pagination
from django.shortcuts import render, get_list_or_404, redirect
from lib2to3.fixes.fix_input import context
from django.core.paginator import Paginator

from goods.models import Service

from carts.models import Cart


# Create your views here.
def cart_add(request, product_slug):
    product = Service.objects.get(slug=product_slug)

    if request.user.is_authenticated:
        carts = Cart.objects.filter(user=request.user, product=product)
        if carts.exists():
            cart = carts.first()
            if cart:
                cart.quantity += 1
                cart.save()
        else:
            Cart.objects.create(user=request.user, product=product, quantity=1)
    return redirect(request.META['HTTP_REFERER'])

def cart_change(request, product_slug):
    pass

def cart_remove(request, product_slug):
    pass