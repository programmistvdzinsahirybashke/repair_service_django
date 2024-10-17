from django.contrib import auth
from django.http import HttpResponse, HttpResponseRedirect
from django.shortcuts import render
from django.urls import reverse

from users.forms import UserLoginForm


# Create your views here.
def login(request):
    if request.method == 'POST':
        form = UserLoginForm(data=request.POST)
        if form.is_valid():
            username = request.POST['username']
            password = request.POST['password']
            user = auth.authenticate(username=username, password=password)
            if user:
                auth.login(request, user)
                return HttpResponseRedirect(reverse('repair_app:index'))
    else:
        form = UserLoginForm()

    context = {
        'title': 'Вход',
        'form': form,
    }
    return render(request, 'users/login.html', context=context)

def registration(request):
    context = {
        'title': 'Регистрация'
    }
    return render(request, 'users/registration.html', context=context)

def profile(request):
    context = {
        'title': 'Мой профиль '
    }
    return render(request, 'users/profile.html', context=context)

def logout(request):
    pass