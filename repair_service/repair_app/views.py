from lib2to3.fixes.fix_input import context

from django.http import HttpResponse
from django.shortcuts import render

# Create your views here.
def index(request):
    context = {
        'title':'RepAir - Главная',
        'content':'Добро пожаловать в сервис ремонта RepAir !',

    }
    return render(request, 'repair_app/index.html', context);

def about(request):
    context = {
        'title': 'О нас',
        'content': 'О сервисе ремонта RepAir',
        'text_on_page':"Мы предоставляем качественные услуги по ремонту микромобильных средств. Наша команда экспертов готова помочь вам с любыми вопросами!",

    }
    return render(request, 'repair_app/about.html', context);
