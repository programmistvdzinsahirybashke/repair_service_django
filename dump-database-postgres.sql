--
-- PostgreSQL database cluster dump
--

-- Started on 2024-12-02 22:38:56

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS;

--
-- User Configurations
--








--
-- Databases
--

--
-- Database "template1" dump
--

\connect template1

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2024-12-02 22:38:56

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- Completed on 2024-12-02 22:38:57

--
-- PostgreSQL database dump complete
--

--
-- Database "postgres" dump
--

\connect postgres

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2024-12-02 22:38:57

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 268 (class 1255 OID 16700)
-- Name: check_employee_before_status_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_employee_before_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, пытаются ли изменить статус на "Выполнено" или "В работе"
    IF NEW.status_id IN (
        SELECT id FROM status WHERE status_name IN ('Выполнено', 'В работе')
    ) THEN
        -- Проверяем, что сотрудник назначен (employee_id не может быть NULL)
        IF NEW.employee_id IS NULL THEN
            RAISE EXCEPTION 'Невозможно изменить статус на "Выполнено" или "В работе", пока не назначен сотрудник';
        END IF;
    END IF;

    -- Возвращаем новую запись (она будет сохранена в базе данных)
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_employee_before_status_change() OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 16702)
-- Name: check_employee_service_category(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_employee_service_category() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Получаем категорию сотрудника
    IF (SELECT category_id FROM employee WHERE id = NEW.employee_id) !=
       (SELECT category_id FROM "Service" WHERE id = NEW.product_id) THEN
        RAISE EXCEPTION 'Категория сотрудника и услуги не совпадают.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_employee_service_category() OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 16683)
-- Name: update_order_item_status_and_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_order_item_status_and_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Если статус изменяется на 4, устанавливаем время завершения работы
    IF NEW.status_id = 3 AND (OLD.status_id IS DISTINCT FROM 3) THEN
        NEW.work_ended_datetime := NOW();
    END IF;

    -- Если устанавливается время завершения работы, меняем статус на 4
    IF NEW.work_ended_datetime IS NOT NULL AND (NEW.status_id IS DISTINCT FROM 3) THEN
        NEW.status_id := 3;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_order_item_status_and_time() OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 16696)
-- Name: update_order_item_status_to_in_progress(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_order_item_status_to_in_progress() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, что сотрудник назначен (не NULL)
    IF NEW.employee_id IS NOT NULL THEN
        -- Меняем статус заявки на "В работе"
        UPDATE order_item
        SET status_id = (SELECT id FROM status WHERE status_name = 'В работе' AND status_category = 'Услуга')
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_order_item_status_to_in_progress() OWNER TO postgres;

--
-- TOC entry 251 (class 1255 OID 16684)
-- Name: update_order_status_and_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_order_status_and_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    invalid_order_items TEXT := ''; -- Переменная для хранения сообщений о заявках с неверным статусом
BEGIN
    -- Проверка на то, чтобы все связанные order_item имели статус 3 перед сменой статуса на 4
    IF NEW.status_id = 4 THEN
        -- Находим order_item, которые не имеют статус 3, и собираем их полную информацию
        SELECT array_to_string(
                   array_agg(
                       (E'\n' || 'Заявка ID: ' || oi.id || 
                       ', Заказ ID: ' || o.id || 
                       ', Услуга: ' || s.service_name || 
                       ', Название: ' || s.service_description || 
                       ', Цена: ' || oi.price::TEXT || 
                       ', Количество: ' || oi.quantity::TEXT || 
                       ', Статус услуги: ' || st.status_name || 
                       ', Сотрудник: ' || u.first_name || ' ' || u.last_name ) 
                   ), '; ') 
        INTO invalid_order_items
        FROM order_item oi
        JOIN "order" o ON oi.order_id = o.id
        LEFT JOIN "Service" s ON oi.product_id = s.id
        LEFT JOIN status st ON oi.status_id = st.id
        LEFT JOIN employee e ON oi.employee_id = e.id
        LEFT JOIN users u ON e.user_id = u.id
        WHERE oi.order_id = NEW.id AND oi.status_id != 3;

        -- Если есть такие order_item, выводим сообщение об ошибке и отменяем изменение
        IF invalid_order_items IS NOT NULL THEN
            RAISE EXCEPTION 'Нельзя изменить статус заказа на 4. Следующие заявки не имеют статус "Выполнено": %', invalid_order_items;
        END IF;

        -- Если проверка пройдена, устанавливаем время завершения заказа
        NEW.order_finished_datetime := NOW();
    END IF;

    -- Если устанавливается время завершения, меняем статус на 4
    IF NEW.order_finished_datetime IS NOT NULL AND (NEW.status_id IS DISTINCT FROM 4) THEN
        NEW.status_id := 4;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_order_status_and_time() OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 16690)
-- Name: update_order_status_based_on_items(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_order_status_based_on_items() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, есть ли хотя бы одна заявка с статусом "В работе"
    IF EXISTS (
        SELECT 1
        FROM order_item
        WHERE order_id = NEW.order_id
        AND status_id = (SELECT id FROM status WHERE status_name = 'В работе')
    ) THEN
        -- Если хотя бы одна заявка в статусе "В работе", меняем статус заказа на "Выполняется"
        UPDATE "order"
        SET status_id = (SELECT id FROM status WHERE status_name = 'Выполняется')
        WHERE id = NEW.order_id;
    -- Если все заявки имеют статус "Выполнено", меняем статус заказа на "Завершено"
    ELSIF NOT EXISTS (
        SELECT 1
        FROM order_item
        WHERE order_id = NEW.order_id
        AND status_id != (SELECT id FROM status WHERE status_name = 'Выполнено')
    ) THEN
        UPDATE "order"
        SET status_id = (SELECT id FROM status WHERE status_name = 'Завершено')
        WHERE id = NEW.order_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_order_status_based_on_items() OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 16688)
-- Name: update_order_status_if_all_items_completed(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_order_status_if_all_items_completed() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, все ли заявки в заказе имеют статус "Выполнено"
    IF NOT EXISTS (
        SELECT 1
        FROM order_item
        WHERE order_id = NEW.order_id
        AND status_id != (SELECT id FROM status WHERE status_name = 'Выполнено')
    ) THEN
        -- Если все заявки выполнены, меняем статус заказа на "Завершено"
        UPDATE "order"
        SET status_id = (SELECT id FROM status WHERE status_name = 'Завершено')
        WHERE id = NEW.order_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_order_status_if_all_items_completed() OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 16685)
-- Name: update_status_and_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_status_and_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка изменения статуса на 4
    IF NEW.status_id = 4 AND (OLD.status_id IS DISTINCT FROM 4) THEN
        IF TG_TABLE_NAME = 'order' THEN
            NEW.order_finished_datetime := NOW();
        ELSIF TG_TABLE_NAME = 'order_item' THEN
            NEW.work_ended_datetime := NOW();
        END IF;
    END IF;

    -- Проверка на установку времени завершения
    IF TG_TABLE_NAME = 'order' AND NEW.order_finished_datetime IS NOT NULL THEN
        NEW.status_id := 4;
    ELSIF TG_TABLE_NAME = 'order_item' AND NEW.work_ended_datetime IS NOT NULL THEN
        NEW.status_id := 4;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_status_and_time() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 16409)
-- Name: Service; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Service" (
    id bigint NOT NULL,
    service_name character varying(200) NOT NULL,
    service_description text,
    price numeric(10,2) NOT NULL,
    slug character varying(200),
    category_id bigint NOT NULL,
    image character varying(100),
    discount numeric(4,2) NOT NULL
);


ALTER TABLE public."Service" OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16408)
-- Name: Service_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."Service" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."Service_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 16441)
-- Name: auth_group; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


ALTER TABLE public.auth_group OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16440)
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 16449)
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_group_permissions OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16448)
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 16435)
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE public.auth_permission OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16434)
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 242 (class 1259 OID 16571)
-- Name: cart; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cart (
    id bigint NOT NULL,
    quantity smallint NOT NULL,
    session_key character varying(32),
    created_timestamp timestamp with time zone NOT NULL,
    product_id bigint NOT NULL,
    user_id bigint,
    CONSTRAINT cart_quantity_check CHECK ((quantity >= 0))
);


ALTER TABLE public.cart OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 16570)
-- Name: cart_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.cart ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cart_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 16397)
-- Name: category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.category (
    id bigint NOT NULL,
    category_name character varying(150) NOT NULL,
    slug character varying(200)
);


ALTER TABLE public.category OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16550)
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id bigint NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE public.django_admin_log OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 16549)
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 224 (class 1259 OID 16427)
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE public.django_content_type OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16426)
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 218 (class 1259 OID 16389)
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE public.django_migrations OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 16388)
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 249 (class 1259 OID 16673)
-- Name: django_session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE public.django_session OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 16503)
-- Name: employee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    user_id bigint NOT NULL
);


ALTER TABLE public.employee OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16502)
-- Name: employee_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.employee ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 219 (class 1259 OID 16396)
-- Name: goods_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.category ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.goods_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 244 (class 1259 OID 16590)
-- Name: order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."order" (
    id bigint NOT NULL,
    created_timestamp timestamp with time zone NOT NULL,
    phone_number character varying(20) NOT NULL,
    requires_delivery boolean NOT NULL,
    delivery_address text,
    payment_on_get boolean NOT NULL,
    comment text,
    is_paid boolean NOT NULL,
    status_id bigint,
    user_id bigint,
    delivery_date date,
    delivery_time time without time zone,
    order_finished_datetime timestamp with time zone
);


ALTER TABLE public."order" OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 16589)
-- Name: order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public."order" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 246 (class 1259 OID 16598)
-- Name: order_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_item (
    id bigint NOT NULL,
    name character varying(150) NOT NULL,
    price numeric(7,2) NOT NULL,
    quantity integer NOT NULL,
    created_timestamp timestamp with time zone NOT NULL,
    order_id bigint NOT NULL,
    product_id bigint,
    status_id bigint,
    employee_id bigint,
    work_ended_datetime timestamp with time zone,
    CONSTRAINT order_item_quantity_check CHECK ((quantity >= 0))
);


ALTER TABLE public.order_item OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 16597)
-- Name: order_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.order_item ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 248 (class 1259 OID 16623)
-- Name: status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.status (
    id bigint NOT NULL,
    status_name character varying(150) NOT NULL,
    status_description character varying(150) NOT NULL,
    status_category character varying(150)
);


ALTER TABLE public.status OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 16622)
-- Name: status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 232 (class 1259 OID 16481)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(150) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(150) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    image character varying(100)
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16491)
-- Name: users_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users_groups (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE public.users_groups OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16490)
-- Name: users_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.users_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 231 (class 1259 OID 16480)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 236 (class 1259 OID 16497)
-- Name: users_user_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users_user_permissions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.users_user_permissions OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16496)
-- Name: users_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.users_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 4989 (class 0 OID 16409)
-- Dependencies: 222
-- Data for Name: Service; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Service" (id, service_name, service_description, price, slug, category_id, image, discount) FROM stdin;
32	Замена тормозов	Замена тормозов электровелосипеда	1400.00	zamena-tormozov-elektrovelo	5	goods_images/elevelo_VZKmZAp.jpg	0.00
25	Диагностика двигателя	Диагностика двигателя вашего электромотоцикла	1250.00	diagnostika-dvigatelya-em	6	goods_images/elemoto_SId7TLS.jpg	10.00
31	Полное техническое обслуживание	Полное техническое обслуживание вашего велосипеда	2500.00	polnoe-tehnicheskoe-obsluzhivanie-velo	2	goods_images/bicycle_frxU6rB.jpg	10.00
29	Замена грипс	Замена грипс руля самоката	200.00	zamena-grips-samokata	3	goods_images/3391409_y5BNh2s.jpg	0.00
49	Замена аккумулятора электромотоцикла	Замена аккумулятора на электромотоцикле	4000.00	zamena-akkumulyatora-elektromotocikla	6	goods_images/elemoto_e3yLJSc.jpg	0.00
36	Замена цепи велосипеда	Замена цепи на велосипеде	1200.00	zamena-tsepi-velosipeda	2	goods_images/bicycle_8pgexP8.jpg	10.00
34	Ремонт тормозов велосипеда	Регулировка и замена тормозных систем велосипеда	800.00	remont-tormozov-velosipeda	2	goods_images/bicycle_oX7ieke.jpg	5.00
46	Ремонт системы зарядки электровелосипеда	Ремонт и настройка системы зарядки электровелосипеда	2000.00	remont-sistemy-zaryadki-elektrovelosipeda	5	goods_images/elevelo_VvGieiX.jpg	5.00
42	Ремонт зарядного устройства электросамоката	Ремонт зарядных устройств для электросамокатов	1200.00	remont-zaryadnogo-ustroystva-elektrosamokata	4	goods_images/elesamo_h8XuMEp.jpg	0.00
37	Ремонт колес самоката	Ремонт и замена колес на самокате	800.00	remont-kolesa-samokata	3	goods_images/3391409_wfi695V.jpg	0.00
38	Ремонт тормозов самоката	Регулировка тормозной системы самоката	500.00	remont-tormozov-samokata	3	goods_images/3391409_zKlHP5S.jpg	5.00
43	Обслуживание тормозной системы электросамоката	Обслуживание и настройка тормозной системы электросамоката	700.00	obsluzhivanie-tormoznoy-sistemy-elektrosamokata	4	goods_images/elesamo_RB7b1oB.jpg	5.00
30	Спицовка колеса	Полная сборка колеса	1000.00	spicovka-kolesa-velosipeda	2	goods_images/bicycle_Xcminxh.jpg	7.00
40	Регулировка рулевой колонки самоката	Настройка рулевой колонки самоката	400.00	regulirovka-rulevoy-kolonki-samokata	3	goods_images/3391409_2B0wXMi.jpg	0.00
27	Замена аккумулятора	Замена аккумулятора электросамоката	2000.00	zamena-akkumulyatora-elektosam	4	goods_images/elesamo_dbHN26V.jpg	10.00
41	Ремонт колес электросамоката	Ремонт и замена колес электросамоката	1000.00	remont-kolesa-elektrosamokata	4	goods_images/elesamo_J4lhBYf.jpg	0.00
44	Ремонт колес электровелосипеда	Ремонт и замена колес электровелосипеда	1500.00	remont-kolesa-elektrovelosipeda	5	goods_images/elevelo_6oFAdjj.jpg	0.00
47	Обслуживание электронных компонентов электровелосипеда	Обслуживание и настройка электронных компонентов электровелосипеда	1200.00	obsluzhivanie-elektronnykh-komponentov-elektrovelosipeda	5	goods_images/elevelo_yc2mEMv.jpg	0.00
48	Ремонт колес электромотоцикла	Ремонт и замена колес электромотоцикла	2000.00	remont-kolesa-elektromotocikla	6	goods_images/elemoto_w5zbTDK.jpg	0.00
45	Замена аккумулятора электровелосипеда	Замена аккумулятора на электровелосипеде	3000.00	zamena-akkumulyatora-elektrovelosipeda	5	goods_images/elevelo_HZJnc9S.jpg	0.00
28	Накачка колес	Накачка колес электросамоката до отказа до взрыва буквально	250.00	nakachka-koles-elektrosam	4	goods_images/elesamo_LOtE31C.jpg	10.00
26	Ремонт камеры	Ремонт (латка) камеры велосипеда	300.00	remont-kamery-velosipeda	2	goods_images/bicycle_9vpWkhw.jpg	0.00
50	Ремонт тормозной системы электромотоцикла	Ремонт и настройка тормозной системы электромотоцикла	1500.00	remont-tormoznoi-sistemy-elektromotocikla	6	goods_images/elemoto_XRSOWqc.jpg	5.00
35	Регулировка переключателей велосипеда	Настройка переключателей на велосипеде	600.00	regulirovka-pereklyuchateley-velosipeda	2	goods_images/bicycle_41d9gDL.jpg	0.00
\.


--
-- TOC entry 4995 (class 0 OID 16441)
-- Dependencies: 228
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_group (id, name) FROM stdin;
\.


--
-- TOC entry 4997 (class 0 OID 16449)
-- Dependencies: 230
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- TOC entry 4993 (class 0 OID 16435)
-- Dependencies: 226
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add log entry	1	add_logentry
2	Can change log entry	1	change_logentry
3	Can delete log entry	1	delete_logentry
4	Can view log entry	1	view_logentry
5	Can add permission	2	add_permission
6	Can change permission	2	change_permission
7	Can delete permission	2	delete_permission
8	Can view permission	2	view_permission
9	Can add group	3	add_group
10	Can change group	3	change_group
11	Can delete group	3	delete_group
12	Can view group	3	view_group
13	Can add content type	4	add_contenttype
14	Can change content type	4	change_contenttype
15	Can delete content type	4	delete_contenttype
16	Can view content type	4	view_contenttype
17	Can add session	5	add_session
18	Can change session	5	change_session
19	Can delete session	5	delete_session
20	Can view session	5	view_session
21	Can add Категорию	6	add_category
22	Can change Категорию	6	change_category
23	Can delete Категорию	6	delete_category
24	Can view Категорию	6	view_category
25	Can add Услугу	7	add_service
26	Can change Услугу	7	change_service
27	Can delete Услугу	7	delete_service
28	Can view Услугу	7	view_service
29	Can add Пользователя	8	add_user
30	Can change Пользователя	8	change_user
31	Can delete Пользователя	8	delete_user
32	Can view Пользователя	8	view_user
33	Can add Сотрудник	9	add_employee
34	Can change Сотрудник	9	change_employee
35	Can delete Сотрудник	9	delete_employee
36	Can view Сотрудник	9	view_employee
37	Can add Корзина	10	add_cart
38	Can change Корзина	10	change_cart
39	Can delete Корзина	10	delete_cart
40	Can view Корзина	10	view_cart
41	Can add Заказ	11	add_order
42	Can change Заказ	11	change_order
43	Can delete Заказ	11	delete_order
44	Can view Заказ	11	view_order
45	Can add Заказанная услуга	12	add_orderitem
46	Can change Заказанная услуга	12	change_orderitem
47	Can delete Заказанная услуга	12	delete_orderitem
48	Can view Заказанная услуга	12	view_orderitem
49	Can add Статус	13	add_status
50	Can change Статус	13	change_status
51	Can delete Статус	13	delete_status
52	Can view Статус	13	view_status
\.


--
-- TOC entry 5009 (class 0 OID 16571)
-- Dependencies: 242
-- Data for Name: cart; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cart (id, quantity, session_key, created_timestamp, product_id, user_id) FROM stdin;
80	1	\N	2024-12-02 22:26:39.417858+03	26	2
\.


--
-- TOC entry 4987 (class 0 OID 16397)
-- Dependencies: 220
-- Data for Name: category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.category (id, category_name, slug) FROM stdin;
1	Все услуги	all
2	Велосипед	velosiped
3	Самокат	samokat
4	Электросамокат	elektrosamokat
5	Электровелосипед	elektrovelosiped
6	Электромотоцикл	elektromotocikl
\.


--
-- TOC entry 5007 (class 0 OID 16550)
-- Dependencies: 240
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
69	2024-12-01 15:26:24.19156+03	8	Услуга Спицовка колеса | Заказ № 14	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
73	2024-12-01 15:30:39.81616+03	35	Услуга Спицовка колеса | Заказ № 24	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
77	2024-12-01 15:32:23.390875+03	24	Заказ № 24 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0421\\u043f\\u0438\\u0446\\u043e\\u0432\\u043a\\u0430 \\u043a\\u043e\\u043b\\u0435\\u0441\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 24", "fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0420\\u0435\\u043c\\u043e\\u043d\\u0442 \\u043a\\u0430\\u043c\\u0435\\u0440\\u044b | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 24", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0433\\u0440\\u0438\\u043f\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 24", "fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
81	2024-12-01 16:24:37.193575+03	25	Заказ № 25 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0430\\u043a\\u043a\\u0443\\u043c\\u0443\\u043b\\u044f\\u0442\\u043e\\u0440\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 25", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
85	2024-12-01 16:29:44.41901+03	26	Заказ № 26 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041d\\u0430\\u043a\\u0430\\u0447\\u043a\\u0430 \\u043a\\u043e\\u043b\\u0435\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 26", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
89	2024-12-01 16:34:49.616824+03	40	Услуга Ремонт камеры | Заказ № 27	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
93	2024-12-01 16:38:40.615736+03	28	Заказ № 28 | Покупатель Денис Сухачев	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
97	2024-12-01 16:41:26.428147+03	42	Услуга Полное техническое обслуживание | Заказ № 28	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
100	2024-12-01 16:42:57.965325+03	29	Заказ № 29 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0433\\u0440\\u0438\\u043f\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 29", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
104	2024-12-01 16:47:34.285968+03	44	Услуга Замена грипс | Заказ № 29	2	[{"changed": {"fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
105	2024-12-01 16:48:52.703925+03	30	Заказ № 30 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041f\\u043e\\u043b\\u043d\\u043e\\u0435 \\u0442\\u0435\\u0445\\u043d\\u0438\\u0447\\u0435\\u0441\\u043a\\u043e\\u0435 \\u043e\\u0431\\u0441\\u043b\\u0443\\u0436\\u0438\\u0432\\u0430\\u043d\\u0438\\u0435 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 30", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
109	2024-12-01 17:13:08.380541+03	34	Ремонт тормозов велосипеда | Велосипед	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
111	2024-12-01 17:13:22.967098+03	26	Ремонт камеры | Велосипед	2	[]	7	2
113	2024-12-01 17:13:40.877729+03	37	Ремонт колес самоката | Самокат	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
116	2024-12-01 17:14:07.065349+03	27	Замена аккумулятора | Электросамокат	2	[]	7	2
1	2024-10-16 19:57:55.776926+03	1	Все услуги и товары	1	[{"added": {}}]	6	1
2	2024-10-16 19:58:05.480165+03	2	Велосипед	1	[{"added": {}}]	6	1
3	2024-10-16 19:58:11.960008+03	3	Самокат	1	[{"added": {}}]	6	1
4	2024-10-16 19:58:28.593056+03	4	Электросамокат	1	[{"added": {}}]	6	1
5	2024-10-16 19:58:36.567016+03	5	Электровелосипед	1	[{"added": {}}]	6	1
6	2024-10-16 19:58:51.515488+03	6	Электромотоцикл	1	[{"added": {}}]	6	1
7	2024-10-16 19:59:34.930208+03	1	Полное техническое обслуживание | Велосипед	1	[{"added": {}}]	7	1
8	2024-10-16 20:00:51.208024+03	2	Спицовка колеса | Велосипед	1	[{"added": {}}]	7	1
9	2024-10-16 20:01:19.996089+03	3	Ремонт камеры | Велосипед	1	[{"added": {}}]	7	1
10	2024-10-16 20:01:54.766579+03	4	Замена аккумулятора | Электросамокат	1	[{"added": {}}]	7	1
11	2024-10-16 20:02:32.407276+03	5	Накачка колес | Электросамокат	1	[{"added": {}}]	7	1
12	2024-10-16 20:03:07.71755+03	6	Замена тормозов | Электровелосипед	1	[{"added": {}}]	7	1
13	2024-10-16 20:03:53.25399+03	7	Диагностика двигателя | Электромотоцикл	1	[{"added": {}}]	7	1
14	2024-10-16 20:06:06.625765+03	1	Все услуги	2	[{"changed": {"fields": ["\\u041d\\u0430\\u0437\\u0432\\u0430\\u043d\\u0438\\u0435"]}}]	6	1
15	2024-10-16 22:33:15.351046+03	8	Замена грипс | Самокат	1	[{"added": {}}]	7	1
16	2024-10-23 19:28:37.865116+03	15	Полное техническое обслуживание | Велосипед	2	[{"changed": {"fields": ["ID \\u043a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u0438"]}}]	7	2
17	2024-10-23 19:28:45.711734+03	15	Полное техническое обслуживание | Велосипед	2	[]	7	2
18	2024-10-23 19:28:52.006318+03	14	Спицовка колеса | Велосипед	2	[{"changed": {"fields": ["ID \\u043a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u0438"]}}]	7	2
19	2024-10-23 19:28:57.136271+03	10	Ремонт камеры | Велосипед	2	[{"changed": {"fields": ["ID \\u043a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u0438"]}}]	7	2
20	2024-10-23 19:29:02.408467+03	13	Замена грипс | Самокат	2	[{"changed": {"fields": ["ID \\u043a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u0438"]}}]	7	2
21	2024-10-23 19:29:09.901851+03	12	Накачка колес | Электросамокат	2	[{"changed": {"fields": ["ID \\u043a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u0438"]}}]	7	2
22	2024-10-23 19:29:27.066504+03	16	Замена тормозов | Электровелосипед	2	[{"changed": {"fields": ["ID \\u043a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u0438"]}}]	7	2
23	2024-10-23 19:29:33.401469+03	11	Замена аккумулятора | Электросамокат	2	[{"changed": {"fields": ["ID \\u043a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u0438"]}}]	7	2
24	2024-10-23 19:29:39.821855+03	9	Диагностика двигателя | Электромотоцикл	2	[{"changed": {"fields": ["ID \\u043a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u0438"]}}]	7	2
25	2024-10-23 19:42:57.305063+03	1	Dope - Велосипед	1	[{"added": {}}]	9	2
26	2024-10-23 19:47:03.410957+03	1	Статус : В обработке	1	[{"added": {}}]	13	2
27	2024-10-23 19:47:21.834641+03	2	Статус : В работе	1	[{"added": {}}]	13	2
28	2024-10-23 19:47:31.122226+03	4	Товар Полное техническое обслуживание | Заказ № 10	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
29	2024-10-23 19:47:51.699824+03	4	Товар Полное техническое обслуживание | Заказ № 10	2	[]	12	2
30	2024-10-23 19:48:35.240658+03	10	Заказ № 10 | Покупатель  	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
31	2024-10-23 19:56:46.136453+03	4	Товар Полное техническое обслуживание | Заказ № 10	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	12	2
32	2024-10-23 20:26:28.144673+03	5	Товар Замена тормозов | Заказ № 11	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	12	2
33	2024-10-23 20:26:44.403739+03	4	Товар Полное техническое обслуживание | Заказ № 10	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	12	2
34	2024-10-23 20:28:18.346661+03	11	Заказ № 11 | Покупатель  	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
35	2024-10-23 20:29:01.214668+03	6	Товар Диагностика двигателя | Заказ № 12	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
36	2024-10-24 10:08:32.937397+03	14	Товар Спицовка колеса | Заказ № 17	2	[{"changed": {"fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443", "\\u0414\\u0430\\u0442\\u0430 \\u0438 \\u0432\\u0440\\u0435\\u043c\\u044f \\u0432\\u044b\\u043f\\u043e\\u043b\\u043d\\u0435\\u043d\\u0438\\u044f"]}}]	12	2
70	2024-12-01 15:27:43.642618+03	27	Услуга Спицовка колеса | Заказ № 19	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
74	2024-12-01 15:30:45.112115+03	35	Услуга Спицовка колеса | Заказ № 24	2	[{"changed": {"fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
78	2024-12-01 16:02:25.836233+03	4	qweelesam	1	[{"added": {}}]	8	2
82	2024-12-01 16:28:23.219706+03	25	Заказ № 25 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0430\\u043a\\u043a\\u0443\\u043c\\u0443\\u043b\\u044f\\u0442\\u043e\\u0440\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 25", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
86	2024-12-01 16:30:19.782467+03	27	Заказ № 27 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0420\\u0435\\u043c\\u043e\\u043d\\u0442 \\u043a\\u0430\\u043c\\u0435\\u0440\\u044b | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 27", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0433\\u0440\\u0438\\u043f\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 27", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
90	2024-12-01 16:34:56.327664+03	41	Услуга Замена грипс | Заказ № 27	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
94	2024-12-01 16:40:27.848348+03	42	Услуга Полное техническое обслуживание | Заказ № 28	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
101	2024-12-01 16:44:51.373942+03	29	Заказ № 29 | Покупатель Денис Сухачев	2	[]	11	2
108	2024-12-01 17:12:53.743734+03	36	Замена цепи велосипеда | Велосипед	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
110	2024-12-01 17:13:18.304308+03	35	Регулировка переключателей велосипеда | Велосипед	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
112	2024-12-01 17:13:31.102226+03	39	Замена аккумулятора самоката | Самокат	3		7	2
71	2024-12-01 15:27:48.73857+03	30	Услуга Замена грипс | Заказ № 21	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
75	2024-12-01 15:31:12.487564+03	35	Услуга Спицовка колеса | Заказ № 24	2	[]	12	2
79	2024-12-01 16:02:39.537919+03	3	qweelesam - Электросамокат	1	[{"added": {}}]	9	2
83	2024-12-01 16:28:33.540668+03	25	Заказ № 25 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0430\\u043a\\u043a\\u0443\\u043c\\u0443\\u043b\\u044f\\u0442\\u043e\\u0440\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 25", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
87	2024-12-01 16:31:27.286762+03	5	Статус : Выполняется	1	[{"added": {}}]	13	2
91	2024-12-01 16:35:02.086041+03	41	Услуга Замена грипс | Заказ № 27	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
95	2024-12-01 16:40:38.403375+03	28	Заказ № 28 | Покупатель Денис Сухачев	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
98	2024-12-01 16:42:25.839437+03	29	Заказ № 29 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0420\\u0435\\u043c\\u043e\\u043d\\u0442 \\u043a\\u0430\\u043c\\u0435\\u0440\\u044b | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 29", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0433\\u0440\\u0438\\u043f\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 29", "fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041d\\u0430\\u043a\\u0430\\u0447\\u043a\\u0430 \\u043a\\u043e\\u043b\\u0435\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 29", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
102	2024-12-01 16:44:58.0197+03	45	Услуга Накачка колес | Заказ № 29	2	[{"changed": {"fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
132	2024-12-02 22:23:40.807273+03	5	ElectroVel	1	[{"added": {}}]	8	2
37	2024-10-31 10:07:04.567418+03	15	Заказ № 15 | Покупатель  	3		11	2
38	2024-10-31 10:07:29.440662+03	14	Заказ № 14 | Покупатель  	3		11	2
39	2024-10-31 10:08:30.418006+03	3	Статус : Выполнено	1	[{"added": {}}]	13	2
40	2024-10-31 10:08:43.620887+03	14	Товар Спицовка колеса | Заказ № 17	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	12	2
41	2024-11-01 09:37:42.505646+03	4	Статус : Завершено	1	[{"added": {}}]	13	2
42	2024-11-01 09:46:02.414806+03	2	Статус : В работе	2	[{"changed": {"fields": ["\\u041a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u044f \\u0441\\u0442\\u0430\\u0442\\u0443\\u0441\\u0430 (\\u0417\\u0430\\u043a\\u0430\\u0437/\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430)"]}}]	13	2
43	2024-11-01 09:46:09.002776+03	4	Статус : Завершено	2	[{"changed": {"fields": ["\\u041a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u044f \\u0441\\u0442\\u0430\\u0442\\u0443\\u0441\\u0430 (\\u0417\\u0430\\u043a\\u0430\\u0437/\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430)"]}}]	13	2
44	2024-11-01 09:46:16.925917+03	3	Статус : Выполнено	2	[{"changed": {"fields": ["\\u041a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u044f \\u0441\\u0442\\u0430\\u0442\\u0443\\u0441\\u0430 (\\u0417\\u0430\\u043a\\u0430\\u0437/\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430)"]}}]	13	2
45	2024-11-01 09:46:44.017727+03	1	Статус : В обработке	2	[{"changed": {"fields": ["\\u041a\\u0430\\u0442\\u0435\\u0433\\u043e\\u0440\\u0438\\u044f \\u0441\\u0442\\u0430\\u0442\\u0443\\u0441\\u0430 (\\u0417\\u0430\\u043a\\u0430\\u0437/\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430)"]}}]	13	2
46	2024-11-08 09:40:07.936803+03	2	1 - Самокат	1	[{"added": {}}]	9	2
47	2024-11-08 09:40:22.896251+03	16	Услуга Замена грипс | Заказ № 17	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
48	2024-11-08 09:50:20.460753+03	12	Услуга Замена грипс | Заказ № 16	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
49	2024-11-08 11:13:41.658739+03	21	Услуга Ремонт камеры | Заказ № 18	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
50	2024-11-08 11:15:18.547785+03	21	Услуга Ремонт камеры | Заказ № 18	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
51	2024-11-08 11:15:37.273478+03	21	Услуга Ремонт камеры | Заказ № 18	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
52	2024-11-08 11:16:33.290513+03	8	Заказ № 8 | Покупатель Джони Дэпп	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
53	2024-11-08 11:16:55.788795+03	10	Заказ № 10 | Покупатель  	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
54	2024-11-08 11:19:28.772568+03	10	Заказ № 10 | Покупатель  	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
55	2024-11-08 11:19:44.390285+03	10	Заказ № 10 | Покупатель  	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
56	2024-11-08 11:49:48.034173+03	26	Услуга Полное техническое обслуживание | Заказ № 19	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
57	2024-11-08 11:50:29.467829+03	28	Услуга Ремонт камеры | Заказ № 19	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
58	2024-11-08 11:50:31.993119+03	27	Услуга Спицовка колеса | Заказ № 19	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
59	2024-11-08 11:50:34.401556+03	19	Заказ № 19 | Покупатель Админ Админ	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
60	2024-11-08 12:58:59.361376+03	28	Услуга Ремонт камеры | Заказ № 19	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
61	2024-11-08 12:59:10.65687+03	22	Услуга Замена грипс | Заказ № 18	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
62	2024-11-08 12:59:18.779964+03	6	Услуга Диагностика двигателя | Заказ № 12	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
63	2024-11-08 13:01:34.776552+03	12	Заказ № 12 | Покупатель Админ Админ	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0414\\u0438\\u0430\\u0433\\u043d\\u043e\\u0441\\u0442\\u0438\\u043a\\u0430 \\u0434\\u0432\\u0438\\u0433\\u0430\\u0442\\u0435\\u043b\\u044f | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 12", "fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
64	2024-11-08 13:06:09.12814+03	13	Заказ № 13 | Покупатель Админ Админ	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0433\\u0440\\u0438\\u043f\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 13", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
65	2024-11-23 12:19:54.873093+03	34	Услуга Полное техническое обслуживание | Заказ № 23	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
66	2024-11-23 12:20:05.565485+03	23	Заказ № 23 | Покупатель Денис Сухачев	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
67	2024-11-23 12:20:27.481774+03	10	Заказ № 10 | Покупатель Админ Админ	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041f\\u043e\\u043b\\u043d\\u043e\\u0435 \\u0442\\u0435\\u0445\\u043d\\u0438\\u0447\\u0435\\u0441\\u043a\\u043e\\u0435 \\u043e\\u0431\\u0441\\u043b\\u0443\\u0436\\u0438\\u0432\\u0430\\u043d\\u0438\\u0435 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 10", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
68	2024-11-23 12:20:33.077843+03	10	Заказ № 10 | Покупатель Админ Админ	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0437\\u0430\\u043a\\u0430\\u0437\\u0430"]}}]	11	2
72	2024-12-01 15:27:54.767417+03	30	Услуга Замена грипс | Заказ № 21	2	[{"changed": {"fields": ["\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
76	2024-12-01 15:31:33.690616+03	37	Услуга Замена грипс | Заказ № 24	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
80	2024-12-01 16:08:01.362044+03	25	Заказ № 25 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0430\\u043a\\u043a\\u0443\\u043c\\u0443\\u043b\\u044f\\u0442\\u043e\\u0440\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 25", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
84	2024-12-01 16:28:45.588306+03	38	Услуга Замена аккумулятора | Заказ № 25	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
88	2024-12-01 16:33:45.802132+03	6	Статус : Обрабатывается	1	[{"added": {}}]	13	2
92	2024-12-01 16:37:55.018151+03	28	Заказ № 28 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041f\\u043e\\u043b\\u043d\\u043e\\u0435 \\u0442\\u0435\\u0445\\u043d\\u0438\\u0447\\u0435\\u0441\\u043a\\u043e\\u0435 \\u043e\\u0431\\u0441\\u043b\\u0443\\u0436\\u0438\\u0432\\u0430\\u043d\\u0438\\u0435 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 28", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
96	2024-12-01 16:41:17.672364+03	42	Услуга Полное техническое обслуживание | Заказ № 28	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	12	2
99	2024-12-01 16:42:47.633344+03	29	Заказ № 29 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0433\\u0440\\u0438\\u043f\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 29", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
103	2024-12-01 16:47:24.387726+03	12	Услуга Замена грипс | Заказ № 16	2	[{"changed": {"fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	12	2
106	2024-12-01 16:53:44.209592+03	30	Заказ № 30 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0421\\u043f\\u0438\\u0446\\u043e\\u0432\\u043a\\u0430 \\u043a\\u043e\\u043b\\u0435\\u0441\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 30", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0420\\u0435\\u043c\\u043e\\u043d\\u0442 \\u043a\\u0430\\u043c\\u0435\\u0440\\u044b | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 30", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
107	2024-12-01 16:54:03.988538+03	30	Заказ № 30 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041f\\u043e\\u043b\\u043d\\u043e\\u0435 \\u0442\\u0435\\u0445\\u043d\\u0438\\u0447\\u0435\\u0441\\u043a\\u043e\\u0435 \\u043e\\u0431\\u0441\\u043b\\u0443\\u0436\\u0438\\u0432\\u0430\\u043d\\u0438\\u0435 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 30", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0421\\u043f\\u0438\\u0446\\u043e\\u0432\\u043a\\u0430 \\u043a\\u043e\\u043b\\u0435\\u0441\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 30", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
114	2024-12-01 17:13:53.017159+03	38	Ремонт тормозов самоката | Самокат	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
115	2024-12-01 17:13:59.919118+03	40	Регулировка рулевой колонки самоката | Самокат	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
117	2024-12-01 17:14:15.430331+03	42	Ремонт зарядного устройства электросамоката | Электросамокат	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
118	2024-12-01 17:14:24.412215+03	41	Ремонт колес электросамоката | Электросамокат	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
119	2024-12-01 17:14:32.663613+03	43	Обслуживание тормозной системы электросамоката | Электросамокат	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
120	2024-12-01 17:14:37.931272+03	28	Накачка колес | Электросамокат	2	[]	7	2
121	2024-12-01 17:14:56.771058+03	45	Замена аккумулятора электровелосипеда | Электровелосипед	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
122	2024-12-01 17:15:04.104198+03	46	Ремонт системы зарядки электровелосипеда | Электровелосипед	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
123	2024-12-01 17:15:09.080212+03	44	Ремонт колес электровелосипеда | Электровелосипед	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
124	2024-12-01 17:15:16.974732+03	47	Обслуживание электронных компонентов электровелосипеда | Электровелосипед	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
125	2024-12-01 17:15:24.747564+03	49	Замена аккумулятора электромотоцикла | Электромотоцикл	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
126	2024-12-01 17:15:41.053991+03	48	Ремонт колес электромотоцикла | Электромотоцикл	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
127	2024-12-01 17:15:47.280399+03	50	Ремонт тормозной системы электромотоцикла | Электромотоцикл	2	[{"changed": {"fields": ["\\u0418\\u0437\\u043e\\u0431\\u0440\\u0430\\u0436\\u0435\\u043d\\u0438\\u0435"]}}]	7	2
128	2024-12-01 22:51:48.527063+03	28	Накачка колес | Электросамокат	2	[{"changed": {"fields": ["\\u0421\\u043a\\u0438\\u0434\\u043a\\u0430 \\u0432 %"]}}]	7	2
129	2024-12-01 22:59:34.193659+03	18	Заказ № 18 | Покупатель Админ Админ	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041f\\u043e\\u043b\\u043d\\u043e\\u0435 \\u0442\\u0435\\u0445\\u043d\\u0438\\u0447\\u0435\\u0441\\u043a\\u043e\\u0435 \\u043e\\u0431\\u0441\\u043b\\u0443\\u0436\\u0438\\u0432\\u0430\\u043d\\u0438\\u0435 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 18", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0421\\u043f\\u0438\\u0446\\u043e\\u0432\\u043a\\u0430 \\u043a\\u043e\\u043b\\u0435\\u0441\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 18", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0430\\u043a\\u043a\\u0443\\u043c\\u0443\\u043b\\u044f\\u0442\\u043e\\u0440\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 18", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041d\\u0430\\u043a\\u0430\\u0447\\u043a\\u0430 \\u043a\\u043e\\u043b\\u0435\\u0441 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 18", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}, {"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0414\\u0438\\u0430\\u0433\\u043d\\u043e\\u0441\\u0442\\u0438\\u043a\\u0430 \\u0434\\u0432\\u0438\\u0433\\u0430\\u0442\\u0435\\u043b\\u044f | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 18", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
130	2024-12-01 23:00:14.163682+03	30	Заказ № 30 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0421\\u043f\\u0438\\u0446\\u043e\\u0432\\u043a\\u0430 \\u043a\\u043e\\u043b\\u0435\\u0441\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 30", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
131	2024-12-01 23:01:47.348394+03	30	Заказ № 30 | Покупатель Денис Сухачев	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u041f\\u043e\\u043b\\u043d\\u043e\\u0435 \\u0442\\u0435\\u0445\\u043d\\u0438\\u0447\\u0435\\u0441\\u043a\\u043e\\u0435 \\u043e\\u0431\\u0441\\u043b\\u0443\\u0436\\u0438\\u0432\\u0430\\u043d\\u0438\\u0435 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 30", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u0414\\u0430\\u0442\\u0430 \\u0438 \\u0432\\u0440\\u0435\\u043c\\u044f \\u0432\\u044b\\u043f\\u043e\\u043b\\u043d\\u0435\\u043d\\u0438\\u044f"]}}]	11	2
133	2024-12-02 22:23:48.004929+03	4	ElectroVel - Электровелосипед	1	[{"added": {}}]	9	2
134	2024-12-02 22:24:19.237907+03	35	Заказ № 35 | Покупатель Админ Админ	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0430\\u043a\\u043a\\u0443\\u043c\\u0443\\u043b\\u044f\\u0442\\u043e\\u0440\\u0430 \\u044d\\u043b\\u0435\\u043a\\u0442\\u0440\\u043e\\u0432\\u0435\\u043b\\u043e\\u0441\\u0438\\u043f\\u0435\\u0434\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 35", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438", "\\u041d\\u0430\\u0437\\u043d\\u0430\\u0447\\u0435\\u043d \\u0441\\u043e\\u0442\\u0440\\u0443\\u0434\\u043d\\u0438\\u043a\\u0443"]}}]	11	2
135	2024-12-02 22:24:54.966988+03	35	Заказ № 35 | Покупатель Админ Админ	2	[{"changed": {"name": "\\u0417\\u0430\\u043a\\u0430\\u0437\\u0430\\u043d\\u043d\\u0430\\u044f \\u0443\\u0441\\u043b\\u0443\\u0433\\u0430", "object": "\\u0423\\u0441\\u043b\\u0443\\u0433\\u0430 \\u0417\\u0430\\u043c\\u0435\\u043d\\u0430 \\u0430\\u043a\\u043a\\u0443\\u043c\\u0443\\u043b\\u044f\\u0442\\u043e\\u0440\\u0430 \\u044d\\u043b\\u0435\\u043a\\u0442\\u0440\\u043e\\u0432\\u0435\\u043b\\u043e\\u0441\\u0438\\u043f\\u0435\\u0434\\u0430 | \\u0417\\u0430\\u043a\\u0430\\u0437 \\u2116 35", "fields": ["\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441 \\u0443\\u0441\\u043b\\u0443\\u0433\\u0438"]}}]	11	2
\.


--
-- TOC entry 4991 (class 0 OID 16427)
-- Dependencies: 224
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.django_content_type (id, app_label, model) FROM stdin;
1	admin	logentry
2	auth	permission
3	auth	group
4	contenttypes	contenttype
5	sessions	session
6	goods	category
7	goods	service
8	users	user
9	users	employee
10	carts	cart
11	orders	order
12	orders	orderitem
13	orders	status
\.


--
-- TOC entry 4985 (class 0 OID 16389)
-- Dependencies: 218
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.django_migrations (id, app, name, applied) FROM stdin;
1	goods	0001_initial	2024-12-01 14:52:31.112573+03
2	goods	0002_alter_category_table	2024-12-01 14:52:31.114059+03
3	goods	0003_alter_category_options_alter_category_category_name_and_more	2024-12-01 14:52:31.12502+03
4	goods	0004_alter_service_options_category_image	2024-12-01 14:52:31.12829+03
5	goods	0005_remove_category_image_service_image	2024-12-01 14:52:31.132606+03
6	goods	0006_service_discount	2024-12-01 14:52:31.136748+03
7	goods	0007_alter_category_options_alter_service_options	2024-12-01 14:52:31.138493+03
8	contenttypes	0001_initial	2024-12-01 14:52:31.142521+03
9	contenttypes	0002_remove_content_type_name	2024-12-01 14:52:31.146171+03
10	auth	0001_initial	2024-12-01 14:52:31.163552+03
11	auth	0002_alter_permission_name_max_length	2024-12-01 14:52:31.165545+03
12	auth	0003_alter_user_email_max_length	2024-12-01 14:52:31.167335+03
13	auth	0004_alter_user_username_opts	2024-12-01 14:52:31.169606+03
14	auth	0005_alter_user_last_login_null	2024-12-01 14:52:31.171861+03
15	auth	0006_require_contenttypes_0002	2024-12-01 14:52:31.172857+03
16	auth	0007_alter_validators_add_error_messages	2024-12-01 14:52:31.175848+03
17	auth	0008_alter_user_username_max_length	2024-12-01 14:52:31.177841+03
18	auth	0009_alter_user_last_name_max_length	2024-12-01 14:52:31.180831+03
19	auth	0010_alter_group_name_max_length	2024-12-01 14:52:31.185814+03
20	auth	0011_update_proxy_permissions	2024-12-01 14:52:31.188804+03
21	auth	0012_alter_user_first_name_max_length	2024-12-01 14:52:31.191795+03
22	users	0001_initial	2024-12-01 14:52:31.217708+03
23	admin	0001_initial	2024-12-01 14:52:31.228671+03
24	admin	0002_logentry_remove_auto_add	2024-12-01 14:52:31.232657+03
25	admin	0003_logentry_add_action_flag_choices	2024-12-01 14:52:31.236644+03
26	carts	0001_initial	2024-12-01 14:52:31.247608+03
27	carts	0002_alter_cart_options	2024-12-01 14:52:31.251595+03
28	goods	0008_alter_service_options	2024-12-01 14:52:31.254585+03
29	orders	0001_initial	2024-12-01 14:52:31.274518+03
30	orders	0002_remove_order_delivery_datetime_order_delivery_date_and_more	2024-12-01 14:52:31.287474+03
31	orders	0003_status_orderitem_status_alter_order_status	2024-12-01 14:52:31.308097+03
32	orders	0004_orderitem_employee	2024-12-01 14:52:31.31607+03
33	orders	0005_alter_order_status_alter_orderitem_employee	2024-12-01 14:52:31.338993+03
34	orders	0006_alter_orderitem_employee_alter_orderitem_status	2024-12-01 14:52:31.355937+03
35	orders	0007_remove_order_work_ended_datetime_and_more	2024-12-01 14:52:31.368969+03
36	orders	0008_status_status_category	2024-12-01 14:52:31.370962+03
37	orders	0009_alter_order_status_alter_orderitem_status	2024-12-01 14:52:31.382006+03
38	sessions	0001_initial	2024-12-01 14:52:31.386467+03
39	orders	0010_alter_orderitem_status	2024-12-01 16:34:14.297739+03
\.


--
-- TOC entry 5016 (class 0 OID 16673)
-- Dependencies: 249
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
98saqt00yt0es4q5jiyv2xsj7i1qgb8r	e30:1t1MiH:pr_hklgf6C4D4GkTIg_MqHcA1rtzEFGMvXe_Y6N1jbM	2024-10-31 12:22:33.132861+03
8i6hnqlwn8cyxyn2j1did78ccpbyaw0n	e30:1t1Nqe:Wpj18JTxOR030OJ9cHrPuQnSHXDl_T_bHEHDRU_Z0Tc	2024-10-31 13:35:16.01965+03
hj6s7k9u8oqw66tkerj2bz9luy4177uz	e30:1t1NrQ:G_GCFElfm6b1fzMDmNFK5OFiujiCk9IkfRpgFgWQNZc	2024-10-31 13:36:04.161962+03
a8c0v6ro0ax39m73t34lmbi97s08dnda	e30:1t29U2:fJkvpe76DTPFANsD5n1IYBHB9BbXxijinieJ2NJAqGY	2024-11-02 16:27:06.353996+03
h0ogv8bu8amgmnaging5cxoo1wcqe2a4	.eJxVjMsOwiAQRf-FtSEWpjxcuu83kGEYpGogKe3K-O_apAvd3nPOfYmA21rC1nkJcxIXMYjT7xaRHlx3kO5Yb01Sq-syR7kr8qBdTi3x83q4fwcFe_nWEBUhqpw8cdJgjAVtXFQGEDI7GPXgEgOobFVktA6sOTuy5Ij9yF68P-xEN_A:1t2DS9:OQVvethGhPx6SmurOCzRW9s8WslY2LqmRoNVSmrYUEw	2024-11-02 20:41:25.598116+03
mbifvodxmlnc0cfr3rr7tgyu31o10a5k	.eJxVjDsOwjAQBe_iGlngbPyhpOcM1np3jQPIluKkQtwdIqWA9s3Me6mI61Li2mWOE6uzMurwuyWkh9QN8B3rrWlqdZmnpDdF77Tra2N5Xnb376BgL98akiFEkzmQ8ADWOhisT8YCQhYP43DyLAAmO5MEnQdnj54ceZIwSlDvD-zdN_E:1t3fWV:Rvro2HTrgdhCh1oa-81n1v_MfA7Y7gPzlEEEMqi7YEg	2024-11-06 20:51:55.682985+03
5qrsogt3tgm06qauylv6gaia0aoa52bl	.eJxVjDsOwjAQBe_iGlngbPyhpOcM1np3jQPIluKkQtwdIqWA9s3Me6mI61Li2mWOE6uzMurwuyWkh9QN8B3rrWlqdZmnpDdF77Tra2N5Xnb376BgL98akiFEkzmQ8ADWOhisT8YCQhYP43DyLAAmO5MEnQdnj54ceZIwSlDvD-zdN_E:1t3rYL:Jxf7gXhRwgaWoXrMJXW2DfywZxrmVvgl33ThrORCHSg	2024-11-07 09:42:37.473784+03
gf09rj3jb4fn93jmxd8imchl8dueulzc	.eJxVjDsOwjAQBe_iGlngbPyhpOcM1np3jQPIluKkQtwdIqWA9s3Me6mI61Li2mWOE6uzMurwuyWkh9QN8B3rrWlqdZmnpDdF77Tra2N5Xnb376BgL98akiFEkzmQ8ADWOhisT8YCQhYP43DyLAAmO5MEnQdnj54ceZIwSlDvD-zdN_E:1tEmGO:9PmaWfgCIGmT99ZeucYRVl_smr6sYpneZz5QeFHNCvg	2024-12-07 12:17:12.257735+03
23bd32rskt2vl4immyvfvbm4l0y80gc1	.eJxVjEEOwiAQRe_C2hAoUKhL9z0DGWYGqRqalHZlvLtt0oVu33v_v0WEbS1xa7zEicRVGHH5ZQnwyfUQ9IB6nyXOdV2mJI9EnrbJcSZ-3c7276BAK_vaWQ8upV4p7TAYCgTGpIAme2QE5B0p1XHAwWu0lkgNDFl3eUi-61l8vvPKOI0:1tHj4w:f9MdP3iG8XQoBgPsSh8ArCEOfeEdRyro8OV815IaT7c	2024-12-15 15:29:34.546302+03
yw4ipc4s5vd67pz5hjiup0sep44i0fzb	.eJxVjEEOwiAQRe_C2hAoUKhL9z0DGWYGqRqalHZlvLtt0oVu33v_v0WEbS1xa7zEicRVGHH5ZQnwyfUQ9IB6nyXOdV2mJI9EnrbJcSZ-3c7276BAK_vaWQ8upV4p7TAYCgTGpIAme2QE5B0p1XHAwWu0lkgNDFl3eUi-61l8vvPKOI0:1tHjbT:faIEQQm3Vx04riecyZJEptw6wxEVy0sNJOmItQxWYyY	2024-12-15 16:03:11.989059+03
c3l62uqz8yv2xq494gak9ncby25478ee	.eJxVjEEOwiAQRe_C2hAoUKhL9z0DGWYGqRqalHZlvLtt0oVu33v_v0WEbS1xa7zEicRVGHH5ZQnwyfUQ9IB6nyXOdV2mJI9EnrbJcSZ-3c7276BAK_vaWQ8upV4p7TAYCgTGpIAme2QE5B0p1XHAwWu0lkgNDFl3eUi-61l8vvPKOI0:1tHjwm:s8UD6tzU4MCDLMU_LIm1_BpprMdkqPHVnQZBBuCYD9U	2024-12-15 16:25:12.029699+03
w80w0j3xoh2hlx3pqcl5t7hm875m04ti	.eJxVjDsOwjAQBe_iGlngbPyhpOcM1np3jQPIluKkQtwdIqWA9s3Me6mI61Li2mWOE6uzMurwuyWkh9QN8B3rrWlqdZmnpDdF77Tra2N5Xnb376BgL98akiFEkzmQ8ADWOhisT8YCQhYP43DyLAAmO5MEnQdnj54ceZIwSlDvD-zdN_E:1tIBbX:RVRp8YYsj7seszUH6t_Zq3cGIoytBAD8545dNZqLbc4	2024-12-16 21:57:07.004344+03
\.


--
-- TOC entry 5005 (class 0 OID 16503)
-- Dependencies: 238
-- Data for Name: employee; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.employee (id, category_id, user_id) FROM stdin;
1	2	1
2	3	2
3	4	4
4	5	5
\.


--
-- TOC entry 5011 (class 0 OID 16590)
-- Dependencies: 244
-- Data for Name: order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."order" (id, created_timestamp, phone_number, requires_delivery, delivery_address, payment_on_get, comment, is_paid, status_id, user_id, delivery_date, delivery_time, order_finished_datetime) FROM stdin;
8	2024-10-22 20:43:32.242579+03	9393113652	f		t	Нужно будет заказать деталь	f	\N	1	2024-10-22	12:00:00	\N
10	2024-10-23 19:43:28.121892+03	9393113650	t	улица Нефтяников 27\r\n119	t		f	2	2	2024-10-25	12:00:00	\N
12	2024-10-23 20:27:57.14409+03	9393113650	t	улица Нефтяников 27\r\n119	f	буду дома	f	1	2	2024-10-24	12:30:00	\N
11	2024-10-23 20:08:30.534184+03	9393113650	f		f	Сюдооо	f	1	2	2024-10-24	12:30:00	\N
13	2024-10-23 20:33:15.309203+03	9393113650	t	Колотушкина 52 кв 152	t	Комментрарарррай	f	1	2	2024-10-24	14:45:00	\N
14	2024-10-24 09:43:06.714464+03	9393113650	f	улица Нефтяников 27\r\n119	f		f	1	2	2024-10-26	15:15:00	\N
15	2024-10-24 09:46:50.552743+03	89393113650	f	улица Нефтяников 27\r\n119	f	адреса не должно быть	f	1	2	2024-10-24	09:30:00	\N
17	2024-10-24 09:59:50.589922+03	89393113650	f		t	адрес написал и нажал кнопку	f	1	2	2024-10-25	12:30:00	\N
19	2024-11-08 11:48:53.406511+03	89393113650	t	улица Нефтяников 27\r\n119	f		f	1	2	2024-11-16	12:15:00	\N
20	2024-11-08 13:26:22.501739+03	79378890643	f		t		f	1	2	2024-11-16	12:15:00	\N
21	2024-11-08 13:29:38.065236+03	79898875643	f		t		f	1	1	2024-11-20	12:45:00	\N
24	2024-12-01 15:30:16.864588+03	79393113655	f		f	rhrthtr	f	1	3	2024-12-05	12:15:00	\N
31	2024-12-02 22:16:18.777803+03	89393113650	f	улица Нефтяников 27\r\n119	t	Занял время	f	1	2	2024-12-02	12:00:00	\N
32	2024-12-02 22:17:02.238029+03	89393113650	f		f		f	1	2	2024-12-02	11:45:00	\N
33	2024-12-02 22:18:03.10973+03	89393113650	f	улица Нефтяников 27\r\n119	t		f	1	2	2024-12-02	10:00:00	\N
25	2024-12-01 16:03:29.896866+03	80098876455	f		t	grreg	f	1	3	2024-12-05	12:30:00	\N
34	2024-12-02 22:19:35.98495+03	89393113650	f		f	Адрес не удалил а просто самовывоз	f	1	2	2024-12-02	09:00:00	\N
26	2024-12-01 16:29:24.414953+03	79178890987	t	sdfg	f	gerger	f	4	3	2024-12-19	15:30:00	2024-12-01 16:29:44.394251+03
27	2024-12-01 16:30:06.046077+03	79378865473	t	erg	f	gerqegr	f	1	3	2024-12-14	08:00:00	\N
28	2024-12-01 16:35:51.702497+03	89393113650	t	улица Нефтяников 27\r\n119	f		f	4	3	2024-12-06	08:00:00	2024-12-01 16:41:26.408631+03
29	2024-12-01 16:41:49.755716+03	89393113650	t	улица Нефтяников 27\r\n119	f	кп	f	5	3	2024-12-12	08:00:00	\N
16	2024-10-24 09:52:19.35726+03	89393113650	f		f	нет	f	5	2	2024-10-26	08:00:00	\N
35	2024-12-02 22:20:14.450267+03	89393113650	t	улица Нефтяников 27\r\n119	t	Доставка по адресу	f	4	2	2024-12-12	14:15:00	2024-12-02 22:24:54.947291+03
36	2024-12-02 22:25:33.810949+03	89393113650	f		f		f	1	2	2024-12-02	08:00:00	\N
37	2024-12-02 22:25:57.619947+03	89393113650	f		t		f	1	2	2024-12-02	08:15:00	\N
18	2024-11-08 10:57:09.197808+03	79171488228	t	Самойлова 54, квартира 27	f	Ровно в 12	f	5	2	2024-11-14	12:00:00	\N
30	2024-12-01 16:48:35.61855+03	89393113650	t	улица Нефтяников 27\r\n119	f		f	4	3	2024-12-13	08:00:00	2024-12-01 23:01:47.317077+03
\.


--
-- TOC entry 5013 (class 0 OID 16598)
-- Dependencies: 246
-- Data for Name: order_item; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_item (id, name, price, quantity, created_timestamp, order_id, product_id, status_id, employee_id, work_ended_datetime) FROM stdin;
48	Ремонт камеры	300.00	1	2024-12-01 16:48:35.630509+03	30	26	3	1	2024-12-01 16:53:44.176336+03
5	Замена тормозов	1400.00	1	2024-10-23 20:08:30.539184+03	11	32	1	\N	\N
4	Полное техническое обслуживание	2250.00	1	2024-10-23 19:43:28.126891+03	10	31	2	1	\N
6	Диагностика двигателя	1125.00	1	2024-10-23 20:27:57.148087+03	12	25	1	\N	\N
7	Замена грипс	200.00	7	2024-10-23 20:33:15.315203+03	13	29	1	\N	\N
9	Ремонт камеры	300.00	3	2024-10-24 09:43:06.732236+03	14	26	1	\N	\N
10	Замена аккумулятора	1800.00	1	2024-10-24 09:43:06.737237+03	14	27	1	\N	\N
11	Полное техническое обслуживание	2250.00	5	2024-10-24 09:46:50.564761+03	15	31	1	\N	\N
13	Полное техническое обслуживание	2250.00	1	2024-10-24 09:59:50.601923+03	17	31	1	\N	\N
15	Ремонт камеры	300.00	1	2024-10-24 09:59:50.612944+03	17	26	1	\N	\N
16	Замена грипс	200.00	4	2024-10-24 09:59:50.617927+03	17	29	1	\N	\N
17	Замена аккумулятора	1800.00	1	2024-10-24 09:59:50.622928+03	17	27	1	\N	\N
18	Накачка колес	250.00	1	2024-10-24 09:59:50.626929+03	17	28	1	\N	\N
14	Спицовка колеса	930.00	2	2024-10-24 09:59:50.607941+03	17	30	1	1	2024-10-24 10:08:26+03
20	Спицовка колеса	930.00	3	2024-11-08 10:57:09.226216+03	18	30	3	1	2024-12-01 22:59:34.151364+03
23	Замена аккумулятора	1800.00	1	2024-11-08 10:57:09.251862+03	18	27	3	3	2024-12-01 22:59:34.151364+03
28	Ремонт камеры	300.00	1	2024-11-08 11:48:53.43653+03	19	26	2	1	\N
22	Замена грипс	200.00	1	2024-11-08 10:57:09.244862+03	18	29	2	2	\N
24	Накачка колес	250.00	4	2024-11-08 10:57:09.256863+03	18	28	3	3	2024-12-01 22:59:34.151364+03
29	Замена грипс	200.00	1	2024-11-08 13:26:22.513758+03	20	29	1	\N	\N
25	Диагностика двигателя	1125.00	1	2024-11-08 10:57:09.262865+03	18	25	6	\N	\N
47	Спицовка колеса	930.00	2	2024-12-01 16:48:35.628515+03	30	30	3	1	2024-12-01 16:54:03.951821+03
19	Полное техническое обслуживание	2250.00	1	2024-11-08 10:57:09.214811+03	18	31	2	1	\N
8	Спицовка колеса	930.00	1	2024-10-24 09:43:06.725234+03	14	30	3	1	2024-12-01 15:26:24.169703+03
27	Спицовка колеса	930.00	1	2024-11-08 11:48:53.429504+03	19	30	2	1	\N
46	Полное техническое обслуживание	2250.00	3	2024-12-01 16:48:35.62453+03	30	31	2	1	\N
30	Замена грипс	200.00	1	2024-11-08 13:29:38.076252+03	21	29	3	2	2024-12-01 15:27:48+03
49	Замена цепи велосипеда	1080.00	1	2024-12-02 22:16:18.785773+03	31	36	6	\N	\N
50	Ремонт камеры	300.00	1	2024-12-02 22:16:18.796912+03	31	26	6	\N	\N
51	Ремонт тормозной системы электромотоцикла	1425.00	2	2024-12-02 22:16:18.798905+03	31	50	6	\N	\N
52	Регулировка переключателей велосипеда	600.00	1	2024-12-02 22:17:02.242016+03	32	35	6	\N	\N
53	Полное техническое обслуживание	2250.00	1	2024-12-02 22:18:03.114714+03	33	31	6	\N	\N
54	Ремонт зарядного устройства электросамоката	1200.00	1	2024-12-02 22:19:35.989933+03	34	42	6	\N	\N
35	Спицовка колеса	930.00	1	2024-12-01 15:30:16.868575+03	24	30	3	\N	2024-12-01 15:30:39+03
36	Ремонт камеры	300.00	1	2024-12-01 15:30:16.871565+03	24	26	3	\N	2024-12-01 15:32:23.366812+03
37	Замена грипс	200.00	1	2024-12-01 15:30:16.872561+03	24	29	3	\N	2024-12-01 15:31:33.674448+03
55	Замена аккумулятора электровелосипеда	3000.00	1	2024-12-02 22:20:14.455251+03	35	45	3	4	2024-12-02 22:24:54.947291+03
56	Ремонт системы зарядки электровелосипеда	1900.00	1	2024-12-02 22:25:33.814936+03	36	46	6	\N	\N
38	Замена аккумулятора	1800.00	1	2024-12-01 16:03:29.906834+03	25	27	3	3	2024-12-01 16:24:37+03
57	Обслуживание тормозной системы электросамоката	665.00	1	2024-12-02 22:25:57.624931+03	37	43	6	\N	\N
39	Накачка колес	250.00	1	2024-12-01 16:29:24.419936+03	26	28	3	3	2024-12-01 16:29:44.394251+03
40	Ремонт камеры	300.00	1	2024-12-01 16:30:06.05106+03	27	26	3	1	2024-12-01 16:30:19+03
41	Замена грипс	200.00	1	2024-12-01 16:30:06.053053+03	27	29	2	\N	\N
42	Полное техническое обслуживание	2250.00	1	2024-12-01 16:35:51.70748+03	28	31	3	1	2024-12-01 16:41:26.408631+03
43	Ремонт камеры	300.00	1	2024-12-01 16:41:49.764686+03	29	26	2	1	\N
45	Накачка колес	250.00	1	2024-12-01 16:41:49.771665+03	29	28	3	\N	2024-12-01 16:42:25+03
12	Замена грипс	200.00	1	2024-10-24 09:52:19.368247+03	16	29	2	2	\N
44	Замена грипс	200.00	1	2024-12-01 16:41:49.76967+03	29	29	3	2	2024-12-01 16:42:57+03
\.


--
-- TOC entry 5015 (class 0 OID 16623)
-- Dependencies: 248
-- Data for Name: status; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.status (id, status_name, status_description, status_category) FROM stdin;
4	Завершено	Заказ полностью завершен	Заказ
3	Выполнено	Услуга выполнена	Услуга
1	В обработке	Принят на обработку	Заказ
2	В работе	Выдан сотруднику на работу	Услуга
5	Выполняется	Заявки в работе (как минимум 1)	Заказ
6	Обрабатывается	Ждет назначения сотруднику	Услуга
\.


--
-- TOC entry 4999 (class 0 OID 16481)
-- Dependencies: 232
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined, image) FROM stdin;
1	pbkdf2_sha256$870000$olZ7qGgV7YyOA01jae51In$VdQMTmj66B/KegNNn5KLnM5ibyQG8B8cJFmUTEU7txQ=	2024-10-19 20:11:28.28101+03	f	Dope	Джони	Дэпп	sfgerg@gmail.com	f	t	2024-10-17 12:55:46.104018+03	users_image/bicycle.jpg
4	1	\N	f	qweelesam	qwe	qwe	qwe@gmail.com	t	t	2024-12-01 16:01:42+03	
3	pbkdf2_sha256$870000$3llY5cMngdfkZEid2O6Ppv$JRXgoms0yTNV0xWBrAIy2EUPKZFJL1IcCkvzAUeUxLA=	2024-12-01 16:25:12.005779+03	f	Deniches	Денис	Сухачев	deniska123procentpass@gmail.com	f	t	2024-11-12 10:27:57.456929+03	
2	pbkdf2_sha256$870000$oYOg2UStzbpHdDPgDb1zfL$KmgoOp+QJL7vU7bmRblBhaFtQbb3vAV5WyYC8qoxPqs=	2024-12-02 21:57:06.982417+03	t	Admin	Админ	Админ	admin@gmail.com	t	t	2024-10-16 19:44:18.004917+03	users_image/4000_x_2250_2.jpg
5	123	\N	f	ElectroVel	ElectroVel	ElectroVel	ElectroVel@gmail.com	f	t	2024-12-02 22:23:10+03	
\.


--
-- TOC entry 5001 (class 0 OID 16491)
-- Dependencies: 234
-- Data for Name: users_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users_groups (id, user_id, group_id) FROM stdin;
\.


--
-- TOC entry 5003 (class 0 OID 16497)
-- Dependencies: 236
-- Data for Name: users_user_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users_user_permissions (id, user_id, permission_id) FROM stdin;
1	4	3
\.


--
-- TOC entry 5022 (class 0 OID 0)
-- Dependencies: 221
-- Name: Service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Service_id_seq"', 50, true);


--
-- TOC entry 5023 (class 0 OID 0)
-- Dependencies: 227
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);


--
-- TOC entry 5024 (class 0 OID 0)
-- Dependencies: 229
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);


--
-- TOC entry 5025 (class 0 OID 0)
-- Dependencies: 225
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auth_permission_id_seq', 52, true);


--
-- TOC entry 5026 (class 0 OID 0)
-- Dependencies: 241
-- Name: cart_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cart_id_seq', 80, true);


--
-- TOC entry 5027 (class 0 OID 0)
-- Dependencies: 239
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.django_admin_log_id_seq', 135, true);


--
-- TOC entry 5028 (class 0 OID 0)
-- Dependencies: 223
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.django_content_type_id_seq', 14, true);


--
-- TOC entry 5029 (class 0 OID 0)
-- Dependencies: 217
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.django_migrations_id_seq', 39, true);


--
-- TOC entry 5030 (class 0 OID 0)
-- Dependencies: 237
-- Name: employee_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.employee_id_seq', 4, true);


--
-- TOC entry 5031 (class 0 OID 0)
-- Dependencies: 219
-- Name: goods_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.goods_category_id_seq', 14, true);


--
-- TOC entry 5032 (class 0 OID 0)
-- Dependencies: 243
-- Name: order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.order_id_seq', 37, true);


--
-- TOC entry 5033 (class 0 OID 0)
-- Dependencies: 245
-- Name: order_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.order_item_id_seq', 57, true);


--
-- TOC entry 5034 (class 0 OID 0)
-- Dependencies: 247
-- Name: status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.status_id_seq', 6, true);


--
-- TOC entry 5035 (class 0 OID 0)
-- Dependencies: 233
-- Name: users_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_groups_id_seq', 1, false);


--
-- TOC entry 5036 (class 0 OID 0)
-- Dependencies: 231
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 5, true);


--
-- TOC entry 5037 (class 0 OID 0)
-- Dependencies: 235
-- Name: users_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_permissions_id_seq', 1, true);


--
-- TOC entry 4743 (class 2606 OID 16415)
-- Name: Service Service_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_pkey" PRIMARY KEY (id);


--
-- TOC entry 4746 (class 2606 OID 16417)
-- Name: Service Service_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_slug_key" UNIQUE (slug);


--
-- TOC entry 4758 (class 2606 OID 16478)
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- TOC entry 4763 (class 2606 OID 16464)
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- TOC entry 4766 (class 2606 OID 16453)
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 4760 (class 2606 OID 16445)
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- TOC entry 4753 (class 2606 OID 16455)
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- TOC entry 4755 (class 2606 OID 16439)
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- TOC entry 4793 (class 2606 OID 16576)
-- Name: cart cart_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_pkey PRIMARY KEY (id);


--
-- TOC entry 4790 (class 2606 OID 16557)
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- TOC entry 4748 (class 2606 OID 16433)
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- TOC entry 4750 (class 2606 OID 16431)
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- TOC entry 4732 (class 2606 OID 16395)
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 4810 (class 2606 OID 16679)
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- TOC entry 4786 (class 2606 OID 16507)
-- Name: employee employee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (id);


--
-- TOC entry 4735 (class 2606 OID 16403)
-- Name: category goods_category_category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_category_name_key UNIQUE (category_name);


--
-- TOC entry 4737 (class 2606 OID 16401)
-- Name: category goods_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_pkey PRIMARY KEY (id);


--
-- TOC entry 4740 (class 2606 OID 16405)
-- Name: category goods_category_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_slug_key UNIQUE (slug);


--
-- TOC entry 4803 (class 2606 OID 16603)
-- Name: order_item order_item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_pkey PRIMARY KEY (id);


--
-- TOC entry 4797 (class 2606 OID 16596)
-- Name: order order_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (id);


--
-- TOC entry 4807 (class 2606 OID 16627)
-- Name: status status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.status
    ADD CONSTRAINT status_pkey PRIMARY KEY (id);


--
-- TOC entry 4774 (class 2606 OID 16495)
-- Name: users_groups users_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 4777 (class 2606 OID 16510)
-- Name: users_groups users_groups_user_id_group_id_fc7788e8_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_user_id_group_id_fc7788e8_uniq UNIQUE (user_id, group_id);


--
-- TOC entry 4768 (class 2606 OID 16487)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4780 (class 2606 OID 16501)
-- Name: users_user_permissions users_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 4783 (class 2606 OID 16524)
-- Name: users_user_permissions users_user_permissions_user_id_permission_id_3b86cbdf_uniq; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_user_id_permission_id_3b86cbdf_uniq UNIQUE (user_id, permission_id);


--
-- TOC entry 4771 (class 2606 OID 16489)
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- TOC entry 4741 (class 1259 OID 16424)
-- Name: Service_category_id_fcdfa058; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Service_category_id_fcdfa058" ON public."Service" USING btree (category_id);


--
-- TOC entry 4744 (class 1259 OID 16423)
-- Name: Service_slug_cab46943_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Service_slug_cab46943_like" ON public."Service" USING btree (slug varchar_pattern_ops);


--
-- TOC entry 4756 (class 1259 OID 16479)
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- TOC entry 4761 (class 1259 OID 16475)
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- TOC entry 4764 (class 1259 OID 16476)
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- TOC entry 4751 (class 1259 OID 16461)
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- TOC entry 4794 (class 1259 OID 16587)
-- Name: cart_product_id_508e72da; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX cart_product_id_508e72da ON public.cart USING btree (product_id);


--
-- TOC entry 4795 (class 1259 OID 16588)
-- Name: cart_user_id_1361a739; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX cart_user_id_1361a739 ON public.cart USING btree (user_id);


--
-- TOC entry 4788 (class 1259 OID 16568)
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);


--
-- TOC entry 4791 (class 1259 OID 16569)
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);


--
-- TOC entry 4808 (class 1259 OID 16681)
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);


--
-- TOC entry 4811 (class 1259 OID 16680)
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);


--
-- TOC entry 4784 (class 1259 OID 16547)
-- Name: employee_category_id_9af3e737; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX employee_category_id_9af3e737 ON public.employee USING btree (category_id);


--
-- TOC entry 4787 (class 1259 OID 16548)
-- Name: employee_user_id_cc4f5a1c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX employee_user_id_cc4f5a1c ON public.employee USING btree (user_id);


--
-- TOC entry 4733 (class 1259 OID 16406)
-- Name: goods_category_category_name_7b12da53_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX goods_category_category_name_7b12da53_like ON public.category USING btree (category_name varchar_pattern_ops);


--
-- TOC entry 4738 (class 1259 OID 16407)
-- Name: goods_category_slug_370bc312_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX goods_category_slug_370bc312_like ON public.category USING btree (slug varchar_pattern_ops);


--
-- TOC entry 4800 (class 1259 OID 16652)
-- Name: order_item_employee_id_193da51a; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_item_employee_id_193da51a ON public.order_item USING btree (employee_id);


--
-- TOC entry 4801 (class 1259 OID 16620)
-- Name: order_item_order_id_0ca9e92e; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_item_order_id_0ca9e92e ON public.order_item USING btree (order_id);


--
-- TOC entry 4804 (class 1259 OID 16621)
-- Name: order_item_product_id_62a1cc4c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_item_product_id_62a1cc4c ON public.order_item USING btree (product_id);


--
-- TOC entry 4805 (class 1259 OID 16646)
-- Name: order_item_status_id_755fd168; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_item_status_id_755fd168 ON public.order_item USING btree (status_id);


--
-- TOC entry 4798 (class 1259 OID 16640)
-- Name: order_status_id_cd54252a; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_status_id_cd54252a ON public."order" USING btree (status_id);


--
-- TOC entry 4799 (class 1259 OID 16609)
-- Name: order_user_id_e323497c; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX order_user_id_e323497c ON public."order" USING btree (user_id);


--
-- TOC entry 4772 (class 1259 OID 16522)
-- Name: users_groups_group_id_2f3517aa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_groups_group_id_2f3517aa ON public.users_groups USING btree (group_id);


--
-- TOC entry 4775 (class 1259 OID 16521)
-- Name: users_groups_user_id_f500bee5; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_groups_user_id_f500bee5 ON public.users_groups USING btree (user_id);


--
-- TOC entry 4778 (class 1259 OID 16536)
-- Name: users_user_permissions_permission_id_6d08dcd2; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_user_permissions_permission_id_6d08dcd2 ON public.users_user_permissions USING btree (permission_id);


--
-- TOC entry 4781 (class 1259 OID 16535)
-- Name: users_user_permissions_user_id_92473840; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_user_permissions_user_id_92473840 ON public.users_user_permissions USING btree (user_id);


--
-- TOC entry 4769 (class 1259 OID 16508)
-- Name: users_username_e8658fc8_like; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_username_e8658fc8_like ON public.users USING btree (username varchar_pattern_ops);


--
-- TOC entry 4833 (class 2620 OID 16703)
-- Name: order_item check_employee_category_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_employee_category_trigger BEFORE INSERT OR UPDATE ON public.order_item FOR EACH ROW WHEN ((new.employee_id IS NOT NULL)) EXECUTE FUNCTION public.check_employee_service_category();


--
-- TOC entry 4834 (class 2620 OID 16701)
-- Name: order_item trigger_check_employee_before_status_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_check_employee_before_status_change BEFORE UPDATE ON public.order_item FOR EACH ROW WHEN ((new.status_id IS DISTINCT FROM old.status_id)) EXECUTE FUNCTION public.check_employee_before_status_change();


--
-- TOC entry 4835 (class 2620 OID 16698)
-- Name: order_item trigger_insert_update_order_item_status; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_insert_update_order_item_status AFTER INSERT ON public.order_item FOR EACH ROW EXECUTE FUNCTION public.update_order_item_status_to_in_progress();


--
-- TOC entry 4836 (class 2620 OID 16697)
-- Name: order_item trigger_update_order_item_status; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_order_item_status AFTER UPDATE ON public.order_item FOR EACH ROW WHEN ((new.employee_id IS DISTINCT FROM old.employee_id)) EXECUTE FUNCTION public.update_order_item_status_to_in_progress();


--
-- TOC entry 4837 (class 2620 OID 16699)
-- Name: order_item trigger_update_order_status; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_order_status AFTER UPDATE ON public.order_item FOR EACH ROW WHEN ((new.status_id IS DISTINCT FROM old.status_id)) EXECUTE FUNCTION public.update_order_status_based_on_items();


--
-- TOC entry 4838 (class 2620 OID 16686)
-- Name: order_item update_order_item_status_time; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_order_item_status_time BEFORE UPDATE ON public.order_item FOR EACH ROW EXECUTE FUNCTION public.update_order_item_status_and_time();


--
-- TOC entry 4832 (class 2620 OID 16687)
-- Name: order update_order_status_time; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_order_status_time BEFORE UPDATE ON public."order" FOR EACH ROW EXECUTE FUNCTION public.update_order_status_and_time();


--
-- TOC entry 4812 (class 2606 OID 16418)
-- Name: Service Service_category_id_fcdfa058_fk_category_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_category_id_fcdfa058_fk_category_id" FOREIGN KEY (category_id) REFERENCES public.category(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4814 (class 2606 OID 16470)
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4815 (class 2606 OID 16465)
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4813 (class 2606 OID 16456)
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4824 (class 2606 OID 16577)
-- Name: cart cart_product_id_508e72da_fk_Service_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT "cart_product_id_508e72da_fk_Service_id" FOREIGN KEY (product_id) REFERENCES public."Service"(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4825 (class 2606 OID 16582)
-- Name: cart cart_user_id_1361a739_fk_users_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_user_id_1361a739_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4822 (class 2606 OID 16558)
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4823 (class 2606 OID 16563)
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_users_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4820 (class 2606 OID 16537)
-- Name: employee employee_category_id_9af3e737_fk_category_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_category_id_9af3e737_fk_category_id FOREIGN KEY (category_id) REFERENCES public.category(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4821 (class 2606 OID 16542)
-- Name: employee employee_user_id_cc4f5a1c_fk_users_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_user_id_cc4f5a1c_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4828 (class 2606 OID 16663)
-- Name: order_item order_item_employee_id_193da51a_fk_employee_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_employee_id_193da51a_fk_employee_id FOREIGN KEY (employee_id) REFERENCES public.employee(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4829 (class 2606 OID 16610)
-- Name: order_item order_item_order_id_0ca9e92e_fk_order_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_order_id_0ca9e92e_fk_order_id FOREIGN KEY (order_id) REFERENCES public."order"(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4830 (class 2606 OID 16615)
-- Name: order_item order_item_product_id_62a1cc4c_fk_Service_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT "order_item_product_id_62a1cc4c_fk_Service_id" FOREIGN KEY (product_id) REFERENCES public."Service"(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4831 (class 2606 OID 16691)
-- Name: order_item order_item_status_id_755fd168_fk_status_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_status_id_755fd168_fk_status_id FOREIGN KEY (status_id) REFERENCES public.status(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4826 (class 2606 OID 16653)
-- Name: order order_status_id_cd54252a_fk_status_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_status_id_cd54252a_fk_status_id FOREIGN KEY (status_id) REFERENCES public.status(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4827 (class 2606 OID 16604)
-- Name: order order_user_id_e323497c_fk_users_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_user_id_e323497c_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4816 (class 2606 OID 16516)
-- Name: users_groups users_groups_group_id_2f3517aa_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_group_id_2f3517aa_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4817 (class 2606 OID 16511)
-- Name: users_groups users_groups_user_id_f500bee5_fk_users_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_user_id_f500bee5_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4818 (class 2606 OID 16530)
-- Name: users_user_permissions users_user_permissio_permission_id_6d08dcd2_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissio_permission_id_6d08dcd2_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4819 (class 2606 OID 16525)
-- Name: users_user_permissions users_user_permissions_user_id_92473840_fk_users_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_user_id_92473840_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


-- Completed on 2024-12-02 22:38:57

--
-- PostgreSQL database dump complete
--

-- Completed on 2024-12-02 22:38:57

--
-- PostgreSQL database cluster dump complete
--

