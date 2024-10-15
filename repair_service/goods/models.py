from django.db import models

# Create your models here.
class Category(models.Model):

    class Meta:
        db_table = 'category'
        verbose_name = 'Категорию'
        verbose_name_plural = 'Категории'

    category_name = models.CharField(max_length=150, unique=True, verbose_name = 'Название')
    slug = models.SlugField(max_length=200, unique=True, blank=True, null=True, verbose_name = 'URL')

    def __str__(self):
        return self.category_name

# Модель для услуг
class Service(models.Model):

    class Meta:
        db_table = 'Service'
        verbose_name = 'Услугу'
        verbose_name_plural = 'Услуги'

    service_name = models.CharField(max_length=200, verbose_name = 'Название услуги')
    category = models.ForeignKey(Category, on_delete=models.CASCADE, verbose_name = 'ID категории')  # Связь с категорией
    service_description = models.TextField(max_length=250, blank=True, null=True, verbose_name = 'Описание')
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name = 'Стоимость')
    slug = models.SlugField(max_length=200, unique=True, blank=True, null=True, verbose_name = 'URL')


    def __str__(self):
        return self.service_name