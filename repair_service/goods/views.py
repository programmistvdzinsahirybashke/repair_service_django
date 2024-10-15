from django.shortcuts import render

# Create your views here.
def catalog(request):
    context = {
        'title':'Каталог услуг',
        'goods': [ ]
    }
    return render(request, 'goods/catalog.html', context)

def product(request):
    return render(request, 'goods/product.html')