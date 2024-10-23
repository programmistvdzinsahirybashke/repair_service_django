from django.contrib.auth.decorators import login_required
from django.contrib import auth, messages
from django.db.models import Prefetch, Sum, F
from django.http import HttpResponse, HttpResponseRedirect
from django.shortcuts import render, redirect
from django.urls import reverse

from carts.models import Cart
from users.forms import UserLoginForm, UserRegistrationForm , ProfileForm

from orders.models import Order, OrderItem


# Create your views here.
def login(request):
    if request.method == 'POST':
        form = UserLoginForm(data=request.POST)
        if form.is_valid():
            username = request.POST['username']
            password = request.POST['password']
            user = auth.authenticate(username=username, password=password)

            session_key = request.session.session_key

            if user:
                auth.login(request, user)
                messages.success(request, f'{username}, Вы вошли в аккаунт')

                if session_key:
                    Cart.objects.filter(session_key=session_key).update(user=user)


                redirect_page = request.POST.get('next', None)
                if redirect_page and redirect_page != reverse('user:logout'):
                    return HttpResponseRedirect(request.POST.get('next'))

                return HttpResponseRedirect(reverse('repair_app:index'))
    else:
        form = UserLoginForm()

    context = {
        'title': 'Вход',
        'form': form,
    }
    return render(request, 'users/login.html', context=context)

def registration(request):
    if request.method == 'POST':
        form = UserRegistrationForm(data=request.POST)
        if form.is_valid():
            form.save()

            session_key = request.session.session_key

            user = form.instance
            auth.login(request, user)

            if session_key:
                Cart.objects.filter(session_key=session_key).update(user=user)

            messages.success(request, f'{user.username}, Вы зарегистрированы и вошли в аккаунт')

            return HttpResponseRedirect(reverse('repair_app:index'))
    else:
        form = UserRegistrationForm()

    context = {
        'title': 'Регистрация',
        'form': form,
    }
    return render(request, 'users/registration.html', context=context)

@login_required
def profile(request):
    if request.method == 'POST':
        form = ProfileForm(data=request.POST, instance=request.user, files=request.FILES)
        if form.is_valid():
            form.save()
            messages.success(request, f'Профиль обновлен')
            return HttpResponseRedirect(reverse('user:profile'))
    else:
        form = ProfileForm(instance=request.user)

    orders = Order.objects.filter(user=request.user).prefetch_related(
        Prefetch(
            "orderitem_set",
            queryset=OrderItem.objects.select_related("product"),
        )
    ).order_by("-id")

    # Вычисляем общую сумму для каждого заказа
    for order in orders:
        order.total = order.orderitem_set.aggregate(
            total=Sum(F('quantity') * F('price'))
        )['total'] or 0

    context = {
        'title': 'Мой профиль',
        'form': form,
        'orders':orders,
    }
    return render(request, 'users/profile.html', context=context)

def users_cart(request):
    return render(request, 'users/users_cart.html')

@login_required
def logout(request):
    messages.success(request, f'Вы вышли из аккаунта')
    auth.logout(request)
    return redirect(reverse('repair_app:index'))