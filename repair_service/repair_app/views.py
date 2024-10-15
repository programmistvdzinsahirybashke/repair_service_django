from lib2to3.fixes.fix_input import context

from django.http import HttpResponse
from django.shortcuts import render

# Create your views here.
def index(request):
    context = {
        'title':'Home',
        'content':'Главная',
        'list':['first', 'second'],
        'dict':{'first':1},
        'logged_in': True,
    }
    return render(request, 'repair_app/index.html', context);

def about(request):
    return HttpResponse('About page');