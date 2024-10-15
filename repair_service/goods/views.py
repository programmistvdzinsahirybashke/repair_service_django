from django.shortcuts import render

from goods.models import Service


# Create your views here.
def catalog(request):

    goods = Service.objects.all();


    context = {
        'title':'Каталог услуг',
        'goods': goods
    }
    return render(request, 'goods/catalog.html', context)

def product(request):
    return render(request, 'goods/product.html')