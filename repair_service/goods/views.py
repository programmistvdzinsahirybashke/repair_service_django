from django.contrib.admin.templatetags.admin_list import pagination
from django.shortcuts import render, get_list_or_404
from goods.models import Service
from lib2to3.fixes.fix_input import context
from django.core.paginator import Paginator

# Create your views here.
def catalog(request, category_slug, ):

    if category_slug == 'all':
        goods = Service.objects.all()
    else:
        goods = get_list_or_404(Service.objects.filter(category__slug=category_slug))

    paginator = Paginator(goods, per_page=3)
    current_page = paginator.page(1)


    context = {
        'title':'Каталог услуг',
        'goods': current_page,
    }
    return render(request, 'goods/catalog.html', context=context)

def product(request, product_slug):

    product = Service.objects.get(slug=product_slug)

    context = {
        'product':product
    }

    return render(request, 'goods/product.html', context=context)