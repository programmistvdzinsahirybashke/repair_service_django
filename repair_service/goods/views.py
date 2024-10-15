from django.shortcuts import render
from goods.models import Service
from lib2to3.fixes.fix_input import context

# Create your views here.
def catalog(request):

    goods = Service.objects.all()

    context = {
        'title':'Каталог услуг',
        'goods': goods,
    }
    return render(request, 'goods/catalog.html', context)

def product(request, product_slug):

    product = Service.objects.get(slug=product_slug)

    context = {
        'product':product
    }

    return render(request, 'goods/product.html', context=context)