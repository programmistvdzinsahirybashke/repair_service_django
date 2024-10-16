from django.shortcuts import render

# Create your views here.
def login(request):
    context = {
        'title': 'Вход'
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