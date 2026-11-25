"""Interfaz de escritorio para administrar MiMascota."""

from __future__ import annotations

import tkinter as tk
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
from tkinter import messagebox, ttk
from typing import Any, Callable

from PIL import Image, ImageOps, ImageTk

try:
    import mysql.connector
    from mysql.connector import Error
except ImportError:
    mysql = None

    class Error(Exception):
        pass


APP_TITLE = "MiMascota | Gestión veterinaria"
BG = "#f2f7f4"
NAVY = "#304c72"
TEAL = "#578e83"
TEXT = "#304148"
MUTED = "#73877f"
WHITE = "#ffffff"
PALE_SURFACE = "#e5efeb"
CARD_BORDER = "#d8e6e1"
HEADER_BG = "#eaf3ef"


def parse_date(value: str) -> date:
    """Convierte una fecha ISO y muestra un error legible si no es válida."""
    try:
        return datetime.strptime(value.strip(), "%Y-%m-%d").date()
    except ValueError as exc:
        raise ValueError("La fecha debe tener el formato AAAA-MM-DD.") from exc


def parse_datetime(value: str) -> datetime:
    """Convierte una fecha y hora ISO, aceptando minutos o segundos."""
    for pattern in ("%Y-%m-%d %H:%M", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value.strip(), pattern)
        except ValueError:
            continue
    raise ValueError("Use el formato AAAA-MM-DD HH:MM, por ejemplo 2026-11-18 09:30.")


def parse_positive_number(value: str, label: str) -> Decimal:
    try:
        number = Decimal(value.strip().replace(",", "."))
    except InvalidOperation as exc:
        raise ValueError(f"{label} debe ser un número válido.") from exc
    if not number.is_finite() or number <= 0:
        raise ValueError(f"{label} debe ser mayor que cero.")
    return number


def parse_positive_integer(value: str, label: str) -> int:
    try:
        number = int(value.strip())
    except ValueError as exc:
        raise ValueError(f"{label} debe ser un número entero.") from exc
    if number <= 0:
        raise ValueError(f"{label} debe ser mayor que cero.")
    return number


class Database:
    def __init__(self, host: str, port: str, database: str, user: str, password: str):
        if mysql is None:
            raise RuntimeError("Falta el conector MySQL. Instale las dependencias con pip install -r requirements.txt.")
        self.connection = mysql.connector.connect(
            host=host.strip(),
            port=int(port),
            database=database.strip(),
            user=user.strip(),
            password=password,
            charset="utf8mb4",
            connection_timeout=5,
        )

    def query(self, sql: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
        with self.connection.cursor(dictionary=True) as cursor:
            cursor.execute(sql, params)
            return list(cursor.fetchall())

    def execute(self, sql: str, params: tuple[Any, ...] = ()) -> int:
        with self.connection.cursor() as cursor:
            cursor.execute(sql, params)
            affected = cursor.rowcount
        self.connection.commit()
        return affected

    def call(self, procedure: str, params: tuple[Any, ...]) -> None:
        with self.connection.cursor() as cursor:
            placeholders = ", ".join(["%s"] * len(params))
            cursor.execute(f"CALL {procedure}({placeholders})", params)
            while cursor.nextset():
                pass
        self.connection.commit()

    def close(self) -> None:
        if self.connection.is_connected():
            self.connection.close()


class LoginFrame(ttk.Frame):
    def __init__(self, parent: tk.Misc, on_connect: Callable[[Database], None]):
        super().__init__(parent, padding=(34, 26))
        self.on_connect = on_connect
        self.columnconfigure(1, weight=1)
        brand = tk.Frame(self, bg=NAVY, padx=18, pady=14)
        brand.grid(row=0, column=0, columnspan=2, sticky="ew", pady=(0, 12))
        tk.Label(
            brand, text="MiMascota", bg=NAVY, fg=WHITE, font=("Segoe UI", 21, "bold")
        ).pack(anchor="w")
        tk.Label(
            brand,
            text="GESTIÓN VETERINARIA",
            bg=NAVY,
            fg="#b8d5e5",
            font=("Segoe UI", 8, "bold"),
        ).pack(anchor="w", pady=(2, 0))
        ttk.Label(
            self,
            text="Conecta la aplicación con tu base de datos local",
            style="Muted.TLabel",
        ).grid(row=1, column=0, columnspan=2, sticky="w", pady=(0, 10))

        self.entries: dict[str, ttk.Entry] = {}
        fields = (
            ("host", "Servidor", "127.0.0.1"),
            ("port", "Puerto", "3306"),
            ("database", "Base de datos", "mimascota"),
            ("user", "Usuario MySQL", "mimascota_app"),
            ("password", "Contraseña", ""),
        )
        for row, (key, label, default) in enumerate(fields, start=2):
            ttk.Label(self, text=label).grid(row=row, column=0, sticky="w", pady=6, padx=(0, 18))
            entry = ttk.Entry(self, show="*" if key == "password" else "")
            entry.insert(0, default)
            entry.grid(row=row, column=1, sticky="ew", pady=6)
            self.entries[key] = entry

        ttk.Label(
            self,
            text="La contraseña se usa solo durante esta sesión y no se guarda.",
            style="Muted.TLabel",
        ).grid(row=7, column=0, columnspan=2, sticky="w", pady=(10, 4))
        ttk.Button(self, text="Conectar",         style="Primary.TButton", command=self.connect).grid(
            row=8, column=0, columnspan=2, sticky="ew", pady=(16, 0)
        )
        self.entries["password"].bind("<Return>", lambda _event: self.connect())
        self.entries["password"].focus_set()

    def connect(self) -> None:
        values = {key: entry.get() for key, entry in self.entries.items()}
        try:
            database = Database(**values)
        except (Error, RuntimeError, ValueError) as exc:
            messagebox.showerror("No se pudo conectar", str(exc), parent=self)
            return
        self.on_connect(database)


class FormDialog(tk.Toplevel):
    def __init__(
        self,
        parent: tk.Misc,
        title: str,
        fields: list[dict[str, Any]],
        on_submit: Callable[[dict[str, Any]], bool | None],
    ):
        super().__init__(parent)
        self.title(title)
        self.configure(bg=BG)
        self.resizable(True, True)
        self.transient(parent.winfo_toplevel())
        self.grab_set()
        self.on_submit = on_submit
        self.controls: dict[str, Any] = {}
        self.fields = fields

        body = ttk.Frame(self, padding=20)
        body.pack(fill="both", expand=True)
        body.columnconfigure(1, weight=1)
        for row, field in enumerate(fields):
            ttk.Label(body, text=field["label"]).grid(
                row=row, column=0, sticky="nw", padx=(0, 14), pady=7
            )
            kind = field.get("kind", "text")
            if kind == "multiline":
                control = tk.Text(body, height=4, width=42, wrap="word", font=("Segoe UI", 10))
                control.grid(row=row, column=1, sticky="ew", pady=7)
                control.insert("1.0", field.get("value", ""))
            elif kind == "choice":
                control = ttk.Combobox(body, state="readonly", width=39)
                options = field.get("options", [])
                control["values"] = [option[0] for option in options]
                control._option_values = {option[0]: option[1] for option in options}
                selected = field.get("value")
                for label, value in options:
                    if value == selected:
                        control.set(label)
                        break
                if not control.get() and options:
                    control.current(0)
                control.grid(row=row, column=1, sticky="ew", pady=7)
            else:
                control = ttk.Entry(body, width=42)
                if field.get("value") is not None:
                    control.insert(0, str(field["value"]))
                control.grid(row=row, column=1, sticky="ew", pady=7)
            self.controls[field["key"]] = control

        buttons = ttk.Frame(body)
        buttons.grid(row=len(fields), column=0, columnspan=2, sticky="e", pady=(14, 0))
        ttk.Button(buttons, text="Cancelar", command=self.destroy).pack(side="right", padx=(8, 0))
        ttk.Button(buttons, text="Guardar", style="Primary.TButton", command=self.submit).pack(
            side="right"
        )
        self.bind("<Escape>", lambda _event: self.destroy())
        self.update_idletasks()
        x = parent.winfo_rootx() + max(0, (parent.winfo_width() - self.winfo_width()) // 2)
        y = parent.winfo_rooty() + max(0, (parent.winfo_height() - self.winfo_height()) // 2)
        self.geometry(f"+{x}+{y}")

    def submit(self) -> None:
        values: dict[str, Any] = {}
        for field in self.fields:
            control = self.controls[field["key"]]
            kind = field.get("kind", "text")
            if kind == "multiline":
                value = control.get("1.0", "end-1c").strip()
            elif kind == "choice":
                label = control.get()
                value = control._option_values.get(label)
            else:
                value = control.get().strip()
            if field.get("required", True) and (value is None or value == ""):
                messagebox.showerror("Dato requerido", f"Completa el campo «{field['label']}».", parent=self)
                return
            values[field["key"]] = value
        if self.on_submit(values) is not False:
            self.destroy()


class DataPage(ttk.Frame):
    def __init__(
        self,
        parent: tk.Misc,
        columns: list[tuple[str, str, int]],
        query: Callable[[], list[dict[str, Any]]],
        id_key: str,
        actions: list[tuple[str, Callable[[], None]]] | None = None,
    ):
        super().__init__(parent, padding=(18, 14))
        self.columns = columns
        self.query = query
        self.id_key = id_key
        self.rows: dict[str, dict[str, Any]] = {}
        self.toolbar = ttk.Frame(self)
        self.toolbar.pack(fill="x", pady=(0, 12))
        self.action_bar = ttk.Frame(self.toolbar)
        self.action_bar.pack(side="left")
        for label, callback in actions or []:
            ttk.Button(self.action_bar, text=label, command=callback).pack(side="left", padx=(0, 8))
        ttk.Button(self.toolbar, text="Actualizar", command=self.refresh).pack(side="right")

        table_frame = ttk.Frame(self)
        table_frame.pack(fill="both", expand=True)
        keys = [column[0] for column in columns]
        self.tree = ttk.Treeview(table_frame, columns=keys, show="headings", selectmode="browse")
        ybar = ttk.Scrollbar(table_frame, orient="vertical", command=self.tree.yview)
        xbar = ttk.Scrollbar(table_frame, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscrollcommand=ybar.set, xscrollcommand=xbar.set)
        self.tree.grid(row=0, column=0, sticky="nsew")
        ybar.grid(row=0, column=1, sticky="ns")
        xbar.grid(row=1, column=0, sticky="ew")
        table_frame.rowconfigure(0, weight=1)
        table_frame.columnconfigure(0, weight=1)
        for key, label, width in columns:
            self.tree.heading(key, text=label)
            self.tree.column(key, width=width, minwidth=70, anchor="w")
        self.tree.tag_configure("even", background="#f7fafc")
        self.tree.tag_configure("odd", background=WHITE)
        self.status = ttk.Label(self, text="", style="Muted.TLabel")
        self.status.pack(anchor="w", pady=(8, 0))

    def selected(self) -> dict[str, Any] | None:
        selection = self.tree.selection()
        if not selection:
            messagebox.showinfo("Selecciona un registro", "Selecciona primero una fila de la tabla.", parent=self)
            return None
        return self.rows.get(selection[0])

    def refresh(self) -> None:
        rows = self.query()
        self.tree.delete(*self.tree.get_children())
        self.rows.clear()
        for index, row in enumerate(rows):
            iid = str(row[self.id_key])
            self.rows[iid] = row
            values = [display_value(row.get(key)) for key, _, _ in self.columns]
            self.tree.insert("", "end", iid=iid, values=values, tags=("even" if index % 2 == 0 else "odd",))
        self.status.configure(text=f"{len(rows)} registro(s)")


class ConsultationPage(ttk.Frame):
    CONSULTATIONS = [
        ("01. Mascotas por propietario", """SELECT p.nombre AS propietario, m.nombre AS mascota,
            m.especie, m.raza, m.estado, COUNT(c.id_cita) AS total_citas,
            COALESCE(SUM(s.precio), 0) AS valor_servicios
            FROM propietarios p
            JOIN mascotas m ON m.id_propietario = p.id_propietario
            LEFT JOIN citas c ON c.id_mascota = m.id_mascota AND c.estado = 'atendida'
            LEFT JOIN servicios s ON s.id_servicio = c.id_servicio
            GROUP BY p.id_propietario, p.nombre, m.id_mascota, m.nombre, m.especie, m.raza, m.estado
            ORDER BY p.nombre, m.nombre"""),
        ("02. Próximas citas por veterinario", """SELECT v.nombre AS veterinario, c.fecha_hora,
            m.nombre AS mascota, s.nombre AS servicio, c.estado
            FROM citas c
            JOIN veterinarios v ON v.id_veterinario = c.id_veterinario
            JOIN mascotas m ON m.id_mascota = c.id_mascota
            JOIN servicios s ON s.id_servicio = c.id_servicio
            WHERE c.fecha_hora BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
              AND c.estado = 'agendada'
            ORDER BY v.nombre, c.fecha_hora"""),
        ("03. Atenciones por especie", """SELECT m.especie, COUNT(h.id_historial) AS total_atenciones
            FROM historial_clinico h JOIN mascotas m ON m.id_mascota = h.id_mascota
            WHERE h.fecha_registro >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
            GROUP BY m.especie ORDER BY total_atenciones DESC"""),
        ("04. Ingresos por servicio y mes", """SELECT s.nombre AS servicio,
            DATE_FORMAT(c.fecha_hora, '%Y-%m') AS mes,
            COUNT(c.id_cita) AS cantidad_atendidas, SUM(s.precio) AS ingresos_totales
            FROM citas c JOIN servicios s ON s.id_servicio = c.id_servicio
            WHERE c.estado = 'atendida'
            GROUP BY s.nombre, DATE_FORMAT(c.fecha_hora, '%Y-%m')
            ORDER BY mes DESC, ingresos_totales DESC"""),
        ("05. Veterinarios con más de 10 citas", """SELECT v.id_veterinario, v.nombre AS veterinario,
            COUNT(c.id_cita) AS citas_atendidas_mes
            FROM veterinarios v JOIN citas c ON c.id_veterinario = v.id_veterinario
            WHERE c.estado = 'atendida'
              AND YEAR(c.fecha_hora) = YEAR(CURDATE())
              AND MONTH(c.fecha_hora) = MONTH(CURDATE())
            GROUP BY v.id_veterinario, v.nombre
            HAVING COUNT(c.id_cita) > 10"""),
        ("06. Vacunas vencidas o próximas", """SELECT p.nombre AS propietario, p.telefono,
            m.nombre AS mascota, vac.nombre AS vacuna, v.fecha_proxima_dosis,
            CASE WHEN v.fecha_proxima_dosis < CURDATE() THEN 'Vencida'
                 ELSE 'Por vencer (<= 15 días)' END AS estado_vacuna
            FROM vacunacion v
            JOIN mascotas m ON m.id_mascota = v.id_mascota
            JOIN propietarios p ON p.id_propietario = m.id_propietario
            JOIN vacunas vac ON vac.id_vacuna = v.id_vacuna
            WHERE m.estado = 'activa'
              AND v.fecha_proxima_dosis <= DATE_ADD(CURDATE(), INTERVAL 15 DAY)
            ORDER BY v.fecha_proxima_dosis ASC"""),
        ("07. Propietarios sin citas recientes", """SELECT p.id_propietario, p.nombre, p.telefono, p.email
            FROM propietarios p
            WHERE p.activo = 1 AND NOT EXISTS (
                SELECT 1 FROM mascotas m JOIN citas c ON c.id_mascota = m.id_mascota
                WHERE m.id_propietario = p.id_propietario
                  AND c.fecha_hora >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
            )"""),
        ("08. Mascota con más atenciones por especie", """SELECT m1.especie, m1.nombre AS mascota,
            COUNT(h1.id_historial) AS total_atenciones
            FROM mascotas m1 JOIN historial_clinico h1 ON h1.id_mascota = m1.id_mascota
            GROUP BY m1.id_mascota, m1.especie, m1.nombre
            HAVING COUNT(h1.id_historial) >= ALL (
                SELECT COUNT(h2.id_historial)
                FROM mascotas m2 JOIN historial_clinico h2 ON h2.id_mascota = m2.id_mascota
                WHERE m2.especie = m1.especie
                GROUP BY m2.id_mascota
            )
            ORDER BY m1.especie, m1.nombre"""),
        ("09. Evolución del peso de una mascota", """SELECT m.nombre AS mascota, h.fecha_registro,
            h.peso AS peso_kg, h.diagnostico
            FROM historial_clinico h JOIN mascotas m ON m.id_mascota = h.id_mascota
            WHERE h.id_mascota = %s
            ORDER BY h.fecha_registro ASC"""),
        ("10. Porcentaje de citas canceladas", """SELECT v.nombre AS veterinario,
            COUNT(c.id_cita) AS total_citas,
            SUM(CASE WHEN c.estado = 'cancelada' THEN 1 ELSE 0 END) AS canceladas,
            ROUND((SUM(CASE WHEN c.estado = 'cancelada' THEN 1 ELSE 0 END) * 100.0)
              / NULLIF(COUNT(c.id_cita), 0), 2) AS porcentaje_canceladas
            FROM veterinarios v LEFT JOIN citas c ON c.id_veterinario = v.id_veterinario
            GROUP BY v.id_veterinario, v.nombre
            ORDER BY porcentaje_canceladas DESC"""),
        ("11. Servicios nunca vendidos", """SELECT s.id_servicio, s.nombre, s.precio
            FROM servicios s LEFT JOIN citas c
              ON c.id_servicio = s.id_servicio AND c.estado = 'atendida'
            WHERE c.id_cita IS NULL"""),
        ("12. Top 5 medicamentos formulados", """SELECT med.nombre AS medicamento,
            med.presentacion, COUNT(pr.id_prescripcion) AS veces_formulado,
            SUM(pr.cantidad) AS unidades_totales
            FROM prescripciones pr JOIN medicamentos med ON med.id_medicamento = pr.id_medicamento
            GROUP BY med.id_medicamento, med.nombre, med.presentacion
            ORDER BY unidades_totales DESC, veces_formulado DESC LIMIT 5"""),
        ("13. Edad promedio por especie", """SELECT especie, COUNT(*) AS cantidad_mascotas,
            ROUND(AVG(TIMESTAMPDIFF(MONTH, fecha_nacimiento, CURDATE()) / 12.0), 1)
              AS edad_promedio_anios
            FROM mascotas WHERE estado = 'activa'
            GROUP BY especie ORDER BY edad_promedio_anios DESC"""),
        ("14. Agenda del día", """SELECT TIME(c.fecha_hora) AS hora, p.nombre AS propietario,
            p.telefono, m.nombre AS mascota, s.nombre AS servicio,
            v.nombre AS veterinario, c.estado
            FROM citas c
            JOIN mascotas m ON m.id_mascota = c.id_mascota
            JOIN propietarios p ON p.id_propietario = m.id_propietario
            JOIN servicios s ON s.id_servicio = c.id_servicio
            JOIN veterinarios v ON v.id_veterinario = c.id_veterinario
            WHERE DATE(c.fecha_hora) = CURDATE()
            ORDER BY c.fecha_hora ASC"""),
        ("15. Resumen ejecutivo de alertas", """SELECT tipo_alerta, prioridad, cantidad FROM (
            SELECT 'Vacunas vencidas o próximas (15 días)' AS tipo_alerta,
                   CASE WHEN COUNT(*) > 5 THEN 'Alta' ELSE 'Media' END AS prioridad,
                   COUNT(*) AS cantidad
            FROM vacunacion
            WHERE fecha_proxima_dosis <= DATE_ADD(CURDATE(), INTERVAL 15 DAY)
            UNION ALL
            SELECT 'Medicamentos con stock bajo (<= 15 unid.)' AS tipo_alerta,
                   CASE WHEN COUNT(*) > 0 THEN 'Alta' ELSE 'Normal' END AS prioridad,
                   COUNT(*) AS cantidad
            FROM medicamentos
            WHERE stock <= 15 AND activo = 1
        ) AS resumen_alertas"""),
    ]

    def __init__(self, parent: tk.Misc, database: Database):
        super().__init__(parent, padding=(18, 14))
        self.db = database
        toolbar = ttk.Frame(self)
        toolbar.pack(fill="x", pady=(0, 12))
        ttk.Label(toolbar, text="Consulta").pack(side="left", padx=(0, 8))
        self.consultation = ttk.Combobox(
            toolbar,
            values=[title for title, _ in self.CONSULTATIONS],
            state="readonly",
            width=46,
        )
        self.consultation.current(0)
        self.consultation.pack(side="left")
        self.pet_frame = ttk.Frame(toolbar)
        ttk.Label(self.pet_frame, text="Mascota").pack(side="left", padx=(12, 8))
        pets = self.db.query(
            """SELECT m.id_mascota, m.nombre, p.nombre AS propietario
               FROM mascotas m JOIN propietarios p ON p.id_propietario = m.id_propietario
               WHERE m.estado = 'activa' ORDER BY m.nombre"""
        )
        self.pet_options = [
            (f"{row['nombre']} · {row['propietario']} (#{row['id_mascota']})", row["id_mascota"])
            for row in pets
        ]
        self.pet_values = {label: value for label, value in self.pet_options}
        self.pet_combobox = ttk.Combobox(
            self.pet_frame,
            values=list(self.pet_values),
            state="readonly",
            width=36,
        )
        if self.pet_options:
            self.pet_combobox.current(0)
        self.pet_combobox.pack(side="left")
        ttk.Button(toolbar, text="Ejecutar", command=self.execute).pack(side="right")
        self.consultation.bind("<<ComboboxSelected>>", lambda _event: self._toggle_pet())

        table_frame = ttk.Frame(self)
        table_frame.pack(fill="both", expand=True)
        self.tree = ttk.Treeview(table_frame, show="headings", selectmode="browse")
        ybar = ttk.Scrollbar(table_frame, orient="vertical", command=self.tree.yview)
        xbar = ttk.Scrollbar(table_frame, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscrollcommand=ybar.set, xscrollcommand=xbar.set)
        self.tree.grid(row=0, column=0, sticky="nsew")
        ybar.grid(row=0, column=1, sticky="ns")
        xbar.grid(row=1, column=0, sticky="ew")
        table_frame.rowconfigure(0, weight=1)
        table_frame.columnconfigure(0, weight=1)
        self.status = ttk.Label(self, text="", style="Muted.TLabel")
        self.status.pack(anchor="w", pady=(8, 0))
        self._toggle_pet()

    def _toggle_pet(self) -> None:
        if self.consultation.current() == 8:
            self.pet_frame.pack(side="left")
        else:
            self.pet_frame.pack_forget()

    def refresh(self) -> None:
        self.execute()

    def execute(self) -> None:
        index = self.consultation.current()
        if index < 0:
            return
        try:
            sql = self.CONSULTATIONS[index][1]
            if index == 8:
                if not self.pet_options:
                    raise ValueError("No hay mascotas activas disponibles.")
                pet_id = self.pet_values[self.pet_combobox.get()]
                rows = self.db.query(sql, (pet_id,))
            else:
                rows = self.db.query(sql)
            self.tree.delete(*self.tree.get_children())
            for key in self.tree["columns"]:
                self.tree.heading(key, text="")
                self.tree.column(key, width=100)
            if not rows:
                self.status.configure(text="0 registro(s)")
                return
            keys = list(rows[0].keys())
            self.tree.configure(columns=keys)
            for key in keys:
                self.tree.heading(key, text=key.replace("_", " ").title())
                self.tree.column(key, width=150, minwidth=70, anchor="w")
            for row_index, row in enumerate(rows):
                self.tree.insert(
                    "",
                    "end",
                    values=[display_value(row.get(key)) for key in keys],
                    tags=("even" if row_index % 2 == 0 else "odd",),
                )
            self.tree.tag_configure("even", background="#f7fafc")
            self.tree.tag_configure("odd", background=WHITE)
            self.status.configure(text=f"{len(rows)} registro(s)")
        except (Error, ValueError) as exc:
            messagebox.showerror("Error en la consulta", str(exc), parent=self)


def build_personalized_search_query(pet_id: str) -> tuple[str, tuple[Any, ...]]:
    try:
        parsed_pet_id = int(pet_id.strip())
    except ValueError as exc:
        raise ValueError("El ID de mascota debe ser un número entero positivo.") from exc
    if parsed_pet_id <= 0:
        raise ValueError("El ID de mascota debe ser un número entero positivo.")

    sql = """SELECT p.id_propietario, p.nombre AS propietario, p.telefono, p.email, p.direccion,
                    m.id_mascota, m.nombre AS mascota, m.especie, m.raza,
                    CASE m.sexo WHEN 'M' THEN 'Macho' ELSE 'Hembra' END AS sexo,
                    m.fecha_nacimiento, m.estado AS estado_mascota,
                    c.id_cita, c.fecha_hora, c.estado AS estado_cita,
                    s.nombre AS servicio, s.precio, v.nombre AS veterinario,
                    h.fecha_registro, h.diagnostico, h.tratamiento, h.peso,
                    COALESCE((
                        SELECT GROUP_CONCAT(
                            CONCAT(med.nombre, ' (', pr.dosis, '; unidades: ', pr.cantidad, ')')
                            SEPARATOR ' | '
                        )
                        FROM prescripciones pr
                        JOIN medicamentos med ON med.id_medicamento = pr.id_medicamento
                        WHERE pr.id_historial = h.id_historial
                    ), '') AS prescripciones,
                    COALESCE((
                        SELECT GROUP_CONCAT(
                            CONCAT(vac.nombre, ' (aplicada: ',
                                   DATE_FORMAT(va.fecha_aplicacion, '%Y-%m-%d'),
                                   ', próxima: ', DATE_FORMAT(va.fecha_proxima_dosis, '%Y-%m-%d'), ')')
                            SEPARATOR ' | '
                        )
                        FROM vacunacion va
                        JOIN vacunas vac ON vac.id_vacuna = va.id_vacuna
                        WHERE va.id_mascota = m.id_mascota
                    ), '') AS vacunas
             FROM mascotas m
             JOIN propietarios p ON p.id_propietario = m.id_propietario
             LEFT JOIN citas c ON c.id_mascota = m.id_mascota
             LEFT JOIN servicios s ON s.id_servicio = c.id_servicio
             LEFT JOIN veterinarios v ON v.id_veterinario = c.id_veterinario
             LEFT JOIN historial_clinico h ON h.id_cita = c.id_cita
             WHERE m.id_mascota = %s
             ORDER BY p.nombre, m.nombre, c.fecha_hora DESC"""
    return sql, (parsed_pet_id,)


class PersonalizedSearchPage(ttk.Frame):
    def __init__(self, parent: tk.Misc, database: Database):
        super().__init__(parent, padding=(18, 14))
        self.db = database

        ttk.Label(
            self,
            text="Ingresa el ID de la mascota para consultar su expediente y toda la información relacionada.",
            style="Muted.TLabel",
        ).pack(anchor="w", pady=(0, 10))
        filters = ttk.Frame(self)
        filters.pack(fill="x", pady=(0, 12))

        id_field = ttk.Frame(filters)
        id_field.pack(side="left", padx=(0, 12))
        ttk.Label(id_field, text="ID de mascota").pack(anchor="w", pady=(0, 4))
        self.pet_id_entry = ttk.Entry(filters, width=14)
        self.pet_id_entry.pack(anchor="w")
        self.pet_id_entry.bind("<Return>", lambda _event: self.search())
        actions = ttk.Frame(filters)
        actions.pack(side="left", pady=(19, 0))
        ttk.Button(actions, text="Buscar", style="Primary.TButton", command=self.search).pack(
            side="left", padx=(0, 6)
        )
        ttk.Button(actions, text="Limpiar", command=self.clear).pack(side="left")

        table_frame = ttk.Frame(self)
        table_frame.pack(fill="both", expand=True)
        self.tree = ttk.Treeview(table_frame, show="headings", selectmode="browse")
        ybar = ttk.Scrollbar(table_frame, orient="vertical", command=self.tree.yview)
        xbar = ttk.Scrollbar(table_frame, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscrollcommand=ybar.set, xscrollcommand=xbar.set)
        self.tree.grid(row=0, column=0, sticky="nsew")
        ybar.grid(row=0, column=1, sticky="ns")
        xbar.grid(row=1, column=0, sticky="ew")
        table_frame.rowconfigure(0, weight=1)
        table_frame.columnconfigure(0, weight=1)
        self.status = ttk.Label(
            self,
            text="Ingresa el ID de la mascota para comenzar.",
            style="Muted.TLabel",
        )
        self.status.pack(anchor="w", pady=(8, 0))

    def search(self) -> None:
        try:
            sql, params = build_personalized_search_query(self.pet_id_entry.get())
            rows = self.db.query(sql, params)
        except (Error, ValueError) as exc:
            messagebox.showerror("No se pudo realizar la búsqueda", str(exc), parent=self)
            return

        self.tree.delete(*self.tree.get_children())
        if not rows:
            self.tree.configure(columns=())
            self.status.configure(text="No se encontraron registros relacionados.")
            return
        keys = list(rows[0].keys())
        self.tree.configure(columns=keys)
        for key in keys:
            self.tree.heading(key, text=key.replace("_", " ").title())
            self.tree.column(key, width=155, minwidth=80, anchor="w")
        for index, row in enumerate(rows):
            self.tree.insert(
                "",
                "end",
                values=[display_value(row.get(key)) for key in keys],
                tags=("even" if index % 2 == 0 else "odd",),
            )
        self.tree.tag_configure("even", background="#f7fafc")
        self.tree.tag_configure("odd", background=WHITE)
        self.status.configure(text=f"{len(rows)} registro(s) relacionado(s)")

    def clear(self) -> None:
        self.pet_id_entry.delete(0, "end")
        self.tree.delete(*self.tree.get_children())
        self.tree.configure(columns=())
        self.status.configure(text="Ingresa el ID de la mascota para comenzar.")


def display_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M")
    if isinstance(value, date):
        return value.strftime("%Y-%m-%d")
    if isinstance(value, float):
        return f"{value:.2f}"
    return str(value)


class MainWindow:
    def __init__(self, root: tk.Tk, database: Database):
        self.root = root
        self.db = database
        self.pages: list[DataPage] = []
        self.root.title(APP_TITLE)
        self.root.geometry("1220x760")
        self.root.minsize(940, 600)
        self.root.configure(bg=BG)
        self.root.protocol("WM_DELETE_WINDOW", self.close)
        self._configure_styles(self.root)
        self._build()

    @staticmethod
    def _configure_styles(root: tk.Tk) -> None:
        style = ttk.Style(root)
        style.theme_use("clam")
        style.configure(".", font=("Segoe UI", 10), foreground=TEXT)
        style.configure("TFrame", background=BG)
        style.configure("TLabel", background=BG, foreground=TEXT)
        style.configure("Muted.TLabel", foreground=MUTED, font=("Segoe UI", 9))
        style.configure("LoginTitle.TLabel", font=("Segoe UI", 24, "bold"), foreground=NAVY)
        style.configure("Header.TLabel", font=("Segoe UI", 20, "bold"), foreground=NAVY)
        style.configure("Subheader.TLabel", font=("Segoe UI", 11, "bold"), foreground=NAVY)
        style.configure(
            "Primary.TButton",
            background=TEAL,
            foreground=WHITE,
            padding=(14, 9),
            borderwidth=0,
            font=("Segoe UI", 9, "bold"),
        )
        style.map(
            "Primary.TButton",
            background=[("disabled", "#b8d0ca"), ("active", "#40786f")],
            foreground=[("disabled", "#f0f5f5")],
        )
        style.configure(
            "TButton",
            background=PALE_SURFACE,
            foreground=NAVY,
            padding=(10, 7),
            borderwidth=0,
            font=("Segoe UI", 9, "bold"),
        )
        style.map(
            "TButton",
            background=[("disabled", "#edf3f0"), ("active", "#d4e4de")],
            foreground=[("disabled", MUTED)],
        )
        style.configure("TEntry", padding=(9, 7), fieldbackground=WHITE, borderwidth=1)
        style.map(
            "TEntry",
            bordercolor=[("focus", TEAL), ("!focus", CARD_BORDER)],
            lightcolor=[("focus", TEAL), ("!focus", CARD_BORDER)],
            darkcolor=[("focus", TEAL), ("!focus", CARD_BORDER)],
        )
        style.configure("TCombobox", padding=(8, 6), fieldbackground=WHITE, borderwidth=1)
        style.map(
            "TCombobox",
            fieldbackground=[("readonly", WHITE), ("focus", WHITE)],
            selectbackground=[("readonly", WHITE)],
            selectforeground=[("readonly", TEXT)],
        )
        style.configure("TNotebook", background=BG, borderwidth=0, tabmargins=(2, 6, 2, 0))
        style.configure(
            "TNotebook.Tab",
            background=PALE_SURFACE,
            foreground=MUTED,
            padding=(13, 10),
            font=("Segoe UI", 9, "bold"),
        )
        style.map(
            "TNotebook.Tab",
            background=[("selected", WHITE), ("active", "#dcebe5")],
            foreground=[("selected", TEAL), ("active", NAVY)],
        )
        style.configure(
            "Treeview",
            background=WHITE,
            fieldbackground=WHITE,
            rowheight=32,
            borderwidth=0,
            font=("Segoe UI", 9),
        )
        style.configure(
            "Treeview.Heading",
            background=PALE_SURFACE,
            foreground=NAVY,
            font=("Segoe UI", 9, "bold"),
            padding=(10, 9),
        )
        style.map(
            "Treeview",
            background=[("selected", "#d8ebe5")],
            foreground=[("selected", NAVY)],
        )

    def _build(self) -> None:
        header = tk.Frame(self.root, bg=HEADER_BG, height=176)
        header.pack(fill="x")
        header.pack_propagate(False)
        self.header_banner = tk.Label(header, bg=HEADER_BG, borderwidth=0)
        self.header_banner.place(x=0, y=0, relwidth=1, relheight=1)
        banner_path = Path(__file__).resolve().parent / "assets" / "mimascota_header.png"
        with Image.open(banner_path) as source:
            self.header_source = source.convert("RGB")
        self.header_banner_size: tuple[int, int] | None = None
        header.bind("<Configure>", self._resize_header_banner)

        tk.Frame(header, bg=TEAL, width=6).place(x=0, y=0, relheight=1)
        branding = tk.Frame(
            header,
            bg="#f8fbf9",
            padx=20,
            pady=15,
            highlightbackground="#d8e6e1",
            highlightthickness=1,
        )
        branding.place(x=28, rely=0.5, anchor="w")
        tk.Label(
            branding, text="MiMascota", bg="#f8fbf9", fg=NAVY, font=("Segoe UI", 25, "bold")
        ).pack(anchor="w")
        tk.Label(
            branding,
            text="CENTRO DE SALUD Y BIENESTAR ANIMAL",
            bg="#f8fbf9",
            fg=TEAL,
            font=("Segoe UI", 9, "bold"),
        ).pack(anchor="w", pady=(4, 0))
        tk.Label(
            branding,
            text="Atención veterinaria con innovación y cuidado",
            bg="#f8fbf9",
            fg=MUTED,
            font=("Segoe UI", 9),
        ).pack(anchor="w", pady=(7, 0))
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=14, pady=(0, 14))
        self._build_dashboard()
        self._build_owners()
        self._build_pets()
        self._build_pet_deletion()
        self._build_appointments()
        self._build_clinical()
        self._build_vaccines()
        self._build_inventory()
        self.consultations = ConsultationPage(self.notebook, self.db)
        self.notebook.add(self.consultations, text="Consultas")
        self.personalized_search = PersonalizedSearchPage(self.notebook, self.db)
        self.notebook.add(self.personalized_search, text="Consulta personalizada")
        self.refresh_all()

    def _resize_header_banner(self, event: tk.Event) -> None:
        size = (event.width, event.height)
        if size[0] < 2 or size[1] < 2 or size == self.header_banner_size:
            return
        banner = ImageOps.fit(
            self.header_source,
            size,
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.38),
        )
        self.header_image = ImageTk.PhotoImage(banner, master=self.root)
        self.header_banner.configure(image=self.header_image)
        self.header_banner_size = size

    def _add_page(
        self,
        title: str,
        columns: list[tuple[str, str, int]],
        query: Callable[[], list[dict[str, Any]]],
        id_key: str,
        actions: list[tuple[str, Callable[[], None]]] | None = None,
    ) -> DataPage:
        page = DataPage(self.notebook, columns, query, id_key, actions)
        self.notebook.add(page, text=title)
        self.pages.append(page)
        return page

    def _build_dashboard(self) -> None:
        self.dashboard = ttk.Frame(self.notebook, padding=24)
        self.notebook.add(self.dashboard, text="Inicio")
        ttk.Label(self.dashboard, text="Resumen del día", style="Header.TLabel").pack(anchor="w")
        self.metrics = ttk.Frame(self.dashboard)
        self.metrics.pack(fill="x", pady=(18, 20))
        self.metric_labels: dict[str, ttk.Label] = {}
        metric_colors = {
            "pets": TEAL,
            "owners": "#6484a6",
            "today": "#9eaf70",
            "stock": "#bd896d",
        }
        for key, title in (
            ("pets", "Mascotas activas"),
            ("owners", "Propietarios activos"),
            ("today", "Citas de hoy"),
            ("stock", "Productos con stock bajo"),
        ):
            card = tk.Frame(
                self.metrics,
                bg=WHITE,
                highlightbackground=CARD_BORDER,
                highlightthickness=1,
            )
            card.pack(side="left", fill="both", expand=True, padx=(0, 12), ipady=12)
            tk.Frame(card, bg=metric_colors[key], height=4).pack(fill="x")
            tk.Label(
                card,
                text=title.upper(),
                bg=WHITE,
                fg=MUTED,
                font=("Segoe UI", 8, "bold"),
            ).pack(
                anchor="w", padx=16, pady=(13, 5)
            )
            label = tk.Label(
                card,
                text="—",
                bg=WHITE,
                fg=metric_colors[key],
                font=("Segoe UI", 26, "bold"),
            )
            label.pack(anchor="w", padx=16, pady=(0, 12))
            self.metric_labels[key] = label
        ttk.Label(self.dashboard, text="Agenda de hoy", style="Subheader.TLabel").pack(anchor="w")
        self.today_table = DataPage(
            self.dashboard,
            [
                ("fecha_hora", "Hora", 150),
                ("mascota", "Mascota", 160),
                ("propietario", "Propietario", 190),
                ("servicio", "Servicio", 180),
                ("veterinario", "Veterinario", 190),
                ("estado", "Estado", 110),
            ],
            self._today_rows,
            "id_cita",
        )
        self.today_table.pack(fill="both", expand=True, pady=(8, 0))

    def _build_owners(self) -> None:
        self.owners = self._add_page(
            "Propietarios",
            [
                ("id_propietario", "ID", 60),
                ("nombre", "Nombre", 190),
                ("telefono", "Teléfono", 130),
                ("email", "Correo", 220),
                ("direccion", "Dirección", 230),
                ("mascotas", "Mascotas activas", 120),
                ("estado", "Estado", 90),
            ],
            lambda: self.db.query(
                """SELECT p.id_propietario, p.nombre, p.telefono, p.email, p.direccion,
                          COUNT(CASE WHEN m.estado = 'activa' THEN 1 END) AS mascotas,
                          IF(p.activo = 1, 'Activo', 'Inactivo') AS estado
                   FROM propietarios p
                   LEFT JOIN mascotas m ON m.id_propietario = p.id_propietario
                   GROUP BY p.id_propietario
                   ORDER BY p.nombre"""
            ),
            "id_propietario",
            [("＋ Nuevo propietario", self.add_owner), ("Editar", self.edit_owner)],
        )

    def _build_pets(self) -> None:
        self.pets = self._add_page(
            "Mascotas",
            [
                ("id_mascota", "ID", 55),
                ("mascota", "Nombre", 140),
                ("especie", "Especie", 100),
                ("raza", "Raza", 140),
                ("sexo", "Sexo", 70),
                ("fecha_nacimiento", "Nacimiento", 120),
                ("propietario", "Propietario", 190),
                ("telefono", "Teléfono", 120),
                ("estado", "Estado", 90),
            ],
            lambda: self.db.query(
                """SELECT id_mascota, mascota, especie, raza,
                          CASE sexo WHEN 'M' THEN 'Macho' ELSE 'Hembra' END AS sexo,
                          fecha_nacimiento, propietario, telefono, estado
                   FROM v_mascota_ficha ORDER BY mascota"""
            ),
            "id_mascota",
            [("＋ Nueva mascota", self.add_pet), ("Editar", self.edit_pet)],
        )

    def _build_pet_deletion(self) -> None:
        self.pet_deletion = self._add_page(
            "Eliminar mascota",
            [
                ("id_mascota", "ID", 65),
                ("mascota", "Nombre", 170),
                ("propietario", "Propietario", 220),
                ("especie", "Especie", 120),
                ("estado", "Estado", 110),
            ],
            lambda: self.db.query(
                """SELECT m.id_mascota, m.nombre AS mascota, p.nombre AS propietario,
                          m.especie, m.estado
                   FROM mascotas m
                   JOIN propietarios p ON p.id_propietario = m.id_propietario
                   ORDER BY m.nombre"""
            ),
            "id_mascota",
            [("Eliminar seleccionada", self.delete_pet)],
        )

    def _build_appointments(self) -> None:
        self.appointments = self._add_page(
            "Citas",
            [
                ("id_cita", "ID", 55),
                ("fecha_hora", "Fecha y hora", 150),
                ("mascota", "Mascota", 140),
                ("propietario", "Propietario", 170),
                ("veterinario", "Veterinario", 170),
                ("servicio", "Servicio", 190),
                ("precio", "Precio", 100),
                ("estado", "Estado", 100),
            ],
            lambda: self.db.query("SELECT * FROM v_agenda ORDER BY fecha_hora DESC LIMIT 500"),
            "id_cita",
            [
                ("＋ Agendar cita", self.add_appointment),
                ("Cancelar cita", self.cancel_appointment),
            ],
        )

    def _build_clinical(self) -> None:
        self.clinical = self._add_page(
            "Atención clínica",
            [
                ("id_historial", "ID", 55),
                ("fecha_registro", "Fecha", 150),
                ("mascota", "Mascota", 140),
                ("veterinario", "Veterinario", 170),
                ("diagnostico", "Diagnóstico", 260),
                ("tratamiento", "Tratamiento", 230),
                ("peso", "Peso (kg)", 90),
            ],
            lambda: self.db.query(
                """SELECT h.id_historial, h.fecha_registro, m.nombre AS mascota,
                          v.nombre AS veterinario, h.diagnostico, h.tratamiento, h.peso
                   FROM historial_clinico h
                   JOIN mascotas m ON m.id_mascota = h.id_mascota
                   JOIN veterinarios v ON v.id_veterinario = h.id_veterinario
                   ORDER BY h.fecha_registro DESC LIMIT 500"""
            ),
            "id_historial",
            [("＋ Registrar atención", self.add_clinical_record)],
        )

    def _build_vaccines(self) -> None:
        self.vaccines = self._add_page(
            "Vacunación",
            [
                ("id_vacunacion", "ID", 55),
                ("fecha_aplicacion", "Aplicación", 120),
                ("fecha_proxima_dosis", "Próxima dosis", 120),
                ("mascota", "Mascota", 150),
                ("vacuna", "Vacuna", 200),
                ("veterinario", "Veterinario", 170),
                ("lote", "Lote", 110),
            ],
            lambda: self.db.query(
                """SELECT va.id_vacunacion, va.fecha_aplicacion, va.fecha_proxima_dosis,
                          m.nombre AS mascota, vu.nombre AS vacuna, ve.nombre AS veterinario, va.lote
                   FROM vacunacion va
                   JOIN mascotas m ON m.id_mascota = va.id_mascota
                   JOIN vacunas vu ON vu.id_vacuna = va.id_vacuna
                   JOIN veterinarios ve ON ve.id_veterinario = va.id_veterinario
                   ORDER BY va.fecha_proxima_dosis"""
            ),
            "id_vacunacion",
            [("＋ Registrar vacuna", self.add_vaccination)],
        )

    def _build_inventory(self) -> None:
        self.inventory = self._add_page(
            "Inventario",
            [
                ("id_medicamento", "ID", 55),
                ("nombre", "Medicamento", 230),
                ("presentacion", "Presentación", 230),
                ("stock", "Unidades", 100),
                ("estado_stock", "Existencia", 130),
                ("activo", "Estado", 100),
            ],
            lambda: self.db.query(
                """SELECT id_medicamento, nombre, presentacion, stock,
                          IF(stock <= 15, 'Stock bajo', 'Disponible') AS estado_stock,
                          IF(activo = 1, 'Activo', 'Inactivo') AS activo
                   FROM medicamentos ORDER BY stock, nombre"""
            ),
            "id_medicamento",
        )

    def _today_rows(self) -> list[dict[str, Any]]:
        return self.db.query(
            """SELECT id_cita, fecha_hora, mascota, propietario, servicio, veterinario, estado
               FROM v_agenda WHERE DATE(fecha_hora) = CURDATE() ORDER BY fecha_hora"""
        )

    def refresh_all(self) -> None:
        try:
            counts = self.db.query(
                """SELECT
                       (SELECT COUNT(*) FROM mascotas WHERE estado = 'activa') AS pets,
                       (SELECT COUNT(*) FROM propietarios WHERE activo = 1) AS owners,
                       (SELECT COUNT(*) FROM citas WHERE DATE(fecha_hora) = CURDATE()) AS today,
                       (SELECT COUNT(*) FROM medicamentos WHERE activo = 1 AND stock <= 15) AS stock"""
            )[0]
            for key, label in self.metric_labels.items():
                label.configure(text=str(counts[key]))
            self.today_table.refresh()
            for page in self.pages:
                page.refresh()
            self.consultations.execute()
        except Error as exc:
            messagebox.showerror("Error al actualizar", str(exc), parent=self.root)

    def perform(self, operation: Callable[[], Any]) -> bool:
        try:
            operation()
            self.refresh_all()
            return True
        except (Error, ValueError) as exc:
            messagebox.showerror("No se pudo guardar", str(exc), parent=self.root)
            return False

    def _owner_options(self, include_id: int | None = None) -> list[tuple[str, int]]:
        rows = self.db.query(
            "SELECT id_propietario, nombre, activo FROM propietarios ORDER BY nombre"
        )
        return [
            (f"{row['nombre']} (#{row['id_propietario']})" + (" · inactivo" if not row["activo"] else ""),
             row["id_propietario"])
            for row in rows
            if row["activo"] or row["id_propietario"] == include_id
        ]

    def _pet_options(self) -> list[tuple[str, int]]:
        rows = self.db.query(
            """SELECT m.id_mascota, m.nombre, p.nombre AS propietario
               FROM mascotas m JOIN propietarios p ON p.id_propietario = m.id_propietario
               WHERE m.estado = 'activa' ORDER BY m.nombre"""
        )
        return [(f"{row['nombre']} · {row['propietario']} (#{row['id_mascota']})", row["id_mascota"]) for row in rows]

    def _active_options(self, table: str, id_key: str) -> list[tuple[str, int]]:
        rows = self.db.query(f"SELECT {id_key}, nombre FROM {table} WHERE activo = 1 ORDER BY nombre")
        return [(f"{row['nombre']} (#{row[id_key]})", row[id_key]) for row in rows]

    def _vaccine_options(self) -> list[tuple[str, int]]:
        rows = self.db.query("SELECT id_vacuna, nombre FROM vacunas ORDER BY nombre")
        return [(f"{row['nombre']} (#{row['id_vacuna']})", row["id_vacuna"]) for row in rows]

    def _open_form(
        self,
        title: str,
        fields: list[dict[str, Any]],
        submit: Callable[[dict[str, Any]], bool | None],
    ) -> None:
        FormDialog(self.root, title, fields, submit)

    def add_owner(self) -> None:
        fields = [
            {"key": "nombre", "label": "Nombre"},
            {"key": "telefono", "label": "Teléfono"},
            {"key": "email", "label": "Correo electrónico", "required": False},
            {"key": "direccion", "label": "Dirección", "required": False},
        ]
        self._open_form("Nuevo propietario", fields, lambda data: self.perform(
            lambda: self.db.execute(
                "INSERT INTO propietarios (nombre, telefono, email, direccion) VALUES (%s, %s, %s, %s)",
                (data["nombre"], data["telefono"], data["email"] or None, data["direccion"] or None),
            )
        ))

    def edit_owner(self) -> None:
        row = self.owners.selected()
        if not row:
            return
        db_row = self.db.query(
            "SELECT * FROM propietarios WHERE id_propietario = %s", (row["id_propietario"],)
        )[0]
        fields = [
            {"key": "nombre", "label": "Nombre", "value": db_row["nombre"]},
            {"key": "telefono", "label": "Teléfono", "value": db_row["telefono"]},
            {"key": "email", "label": "Correo electrónico", "value": db_row["email"], "required": False},
            {"key": "direccion", "label": "Dirección", "value": db_row["direccion"], "required": False},
            {
                "key": "activo",
                "label": "Estado",
                "kind": "choice",
                "options": [("Activo", 1), ("Inactivo", 0)],
                "value": db_row["activo"],
            },
        ]
        self._open_form("Editar propietario", fields, lambda data: self.perform(
            lambda: self.db.execute(
                """UPDATE propietarios SET nombre=%s, telefono=%s, email=%s, direccion=%s, activo=%s
                   WHERE id_propietario=%s""",
                (data["nombre"], data["telefono"], data["email"] or None, data["direccion"] or None,
                 data["activo"], db_row["id_propietario"]),
            )
        ))

    def _pet_fields(self, row: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        owner_id = row["id_propietario"] if row else None
        return [
            {"key": "nombre", "label": "Nombre", "value": row["nombre"] if row else ""},
            {"key": "id_propietario", "label": "Propietario", "kind": "choice",
             "options": self._owner_options(owner_id), "value": owner_id},
            {"key": "especie", "label": "Especie", "value": row["especie"] if row else ""},
            {"key": "raza", "label": "Raza", "value": row["raza"] if row else "", "required": False},
            {"key": "sexo", "label": "Sexo", "kind": "choice",
             "options": [("Macho", "M"), ("Hembra", "H")], "value": row["sexo"] if row else None},
            {"key": "fecha_nacimiento", "label": "Nacimiento (AAAA-MM-DD)",
             "value": display_value(row["fecha_nacimiento"]) if row else ""},
        ] + ([{"key": "estado", "label": "Estado", "kind": "choice",
               "options": [(x.title(), x) for x in ("activa", "fallecida", "adoptada")],
               "value": row["estado"]}] if row else [])

    def add_pet(self) -> None:
        self._open_form("Nueva mascota", self._pet_fields(), lambda data: self.perform(
            lambda: self.db.execute(
                """INSERT INTO mascotas
                   (id_propietario, nombre, especie, raza, sexo, fecha_nacimiento)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (data["id_propietario"], data["nombre"], data["especie"], data["raza"] or None,
                 data["sexo"], parse_date(data["fecha_nacimiento"])),
            )
        ))

    def edit_pet(self) -> None:
        selected = self.pets.selected()
        if not selected:
            return
        row = self.db.query(
            "SELECT * FROM mascotas WHERE id_mascota = %s", (selected["id_mascota"],)
        )[0]

        def save(data: dict[str, Any]) -> bool:
            if data["id_propietario"] != row["id_propietario"]:
                confirmed = messagebox.askyesno(
                    "Cambio de propietario",
                    "El cambio quedará registrado en el historial de propietarios. ¿Deseas continuar?",
                    parent=self.root,
                )
                if not confirmed:
                    return False
            return self.perform(lambda: self.db.execute(
                """UPDATE mascotas SET id_propietario=%s, nombre=%s, especie=%s, raza=%s, sexo=%s,
                       fecha_nacimiento=%s, estado=%s WHERE id_mascota=%s""",
                (data["id_propietario"], data["nombre"], data["especie"], data["raza"] or None,
                 data["sexo"], parse_date(data["fecha_nacimiento"]), data["estado"], row["id_mascota"]),
            ))

        self._open_form("Editar mascota", self._pet_fields(row), save)

    def delete_pet(self) -> None:
        row = self.pet_deletion.selected()
        if not row:
            return
        if not messagebox.askyesno(
            "Eliminar mascota",
            f"¿Eliminar permanentemente a {row['mascota']} (ID {row['id_mascota']})?\n\n"
            "También se eliminarán sus citas, atenciones clínicas, recetas, vacunas y cambios "
            "de propietario. Esta acción no se puede deshacer.",
            parent=self.root,
        ):
            return
        try:
            self.db.call("sp_eliminar_mascota", (row["id_mascota"],))
            self.refresh_all()
            messagebox.showinfo(
                "Eliminación completada",
                f"Se eliminó a {row['mascota']} y sus registros relacionados.",
                parent=self.root,
            )
        except Error as exc:
            messagebox.showerror(
                "No se pudo eliminar la mascota",
                str(exc),
                parent=self.root,
            )

    def add_appointment(self) -> None:
        fields = [
            {"key": "id_mascota", "label": "Mascota", "kind": "choice", "options": self._pet_options()},
            {"key": "id_veterinario", "label": "Veterinario", "kind": "choice",
             "options": self._active_options("veterinarios", "id_veterinario")},
            {"key": "id_servicio", "label": "Servicio", "kind": "choice",
             "options": self._active_options("servicios", "id_servicio")},
            {"key": "fecha_hora", "label": "Fecha y hora (AAAA-MM-DD HH:MM)",
             "value": datetime.now().replace(second=0, microsecond=0).strftime("%Y-%m-%d %H:%M")},
        ]
        self._open_form("Agendar cita", fields, lambda data: self.perform(
            lambda: self.db.call(
                "sp_agendar_cita",
                (data["id_mascota"], data["id_veterinario"], data["id_servicio"],
                 parse_datetime(data["fecha_hora"])),
            )
        ))

    def cancel_appointment(self) -> None:
        row = self.appointments.selected()
        if not row:
            return
        if row["estado"] != "agendada":
            messagebox.showinfo("No disponible", "Solo se pueden cancelar citas agendadas.", parent=self.root)
            return
        if messagebox.askyesno("Cancelar cita", "¿Deseas cancelar la cita seleccionada?", parent=self.root):
            self.perform(lambda: self.db.execute(
                "UPDATE citas SET estado = 'cancelada' WHERE id_cita = %s AND estado = 'agendada'",
                (row["id_cita"],),
            ))

    def add_clinical_record(self) -> None:
        appointments = self.db.query(
            """SELECT c.id_cita, c.fecha_hora, m.nombre AS mascota, v.nombre AS veterinario
               FROM citas c JOIN mascotas m ON m.id_mascota = c.id_mascota
               JOIN veterinarios v ON v.id_veterinario = c.id_veterinario
               WHERE c.estado = 'agendada' ORDER BY c.fecha_hora"""
        )
        appointment_options = [
            (f"#{row['id_cita']} · {display_value(row['fecha_hora'])} · {row['mascota']} · {row['veterinario']}",
             row["id_cita"])
            for row in appointments
        ]
        if not appointment_options:
            messagebox.showinfo("Sin citas pendientes", "No hay citas agendadas para atender.", parent=self.root)
            return
        medication_options = [("Sin medicamento", None)] + self._active_options("medicamentos", "id_medicamento")
        fields = [
            {"key": "id_cita", "label": "Cita agendada", "kind": "choice", "options": appointment_options},
            {"key": "diagnostico", "label": "Diagnóstico", "kind": "multiline"},
            {"key": "tratamiento", "label": "Tratamiento", "kind": "multiline", "required": False},
            {"key": "peso", "label": "Peso (kg)"},
            {"key": "id_medicamento", "label": "Medicamento", "kind": "choice", "options": medication_options},
            {"key": "dosis", "label": "Dosis", "required": False},
            {"key": "cantidad", "label": "Unidades", "value": "1", "required": False},
        ]

        def save(data: dict[str, Any]) -> bool:
            weight = parse_positive_number(data["peso"], "El peso")
            med_id = data["id_medicamento"]
            if med_id is not None and not data["dosis"]:
                raise ValueError("Indica la dosis del medicamento.")
            quantity = parse_positive_integer(data["cantidad"], "La cantidad") if med_id is not None else 0
            return self.perform(lambda: self.db.call(
                "sp_registrar_atencion",
                (data["id_cita"], data["diagnostico"], data["tratamiento"] or None, weight,
                 med_id, data["dosis"] or None, quantity),
            ))

        self._open_form("Registrar atención clínica", fields, save)

    def add_vaccination(self) -> None:
        fields = [
            {"key": "id_mascota", "label": "Mascota", "kind": "choice", "options": self._pet_options()},
            {"key": "id_vacuna", "label": "Vacuna", "kind": "choice",
             "options": self._vaccine_options()},
            {"key": "id_veterinario", "label": "Veterinario", "kind": "choice",
             "options": self._active_options("veterinarios", "id_veterinario")},
            {"key": "fecha_aplicacion", "label": "Aplicación (AAAA-MM-DD)",
             "value": date.today().isoformat()},
            {"key": "fecha_proxima_dosis", "label": "Próxima dosis (AAAA-MM-DD)"},
            {"key": "lote", "label": "Lote", "required": False},
        ]
        self._open_form("Registrar vacunación", fields, lambda data: self.perform(
            lambda: self.db.execute(
                """INSERT INTO vacunacion
                   (id_mascota, id_vacuna, id_veterinario, fecha_aplicacion, fecha_proxima_dosis, lote)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (data["id_mascota"], data["id_vacuna"], data["id_veterinario"],
                 parse_date(data["fecha_aplicacion"]), parse_date(data["fecha_proxima_dosis"]),
                 data["lote"] or None),
            )
        ))

    def close(self) -> None:
        self.db.close()
        self.root.destroy()


class LoginWindow:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title(APP_TITLE)
        self.root.geometry("510x500")
        self.root.resizable(False, False)
        self.root.configure(bg=BG)
        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() - 510) // 2
        y = (self.root.winfo_screenheight() - 500) // 2
        self.root.geometry(f"510x500+{x}+{y}")
        MainWindow._configure_styles(root)
        LoginFrame(root, self.connected).pack(fill="both", expand=True)

    def connected(self, database: Database) -> None:
        for child in self.root.winfo_children():
            child.destroy()
        MainWindow(self.root, database)


def main() -> None:
    root = tk.Tk()
    if mysql is None:
        root.withdraw()
        messagebox.showerror(
            "Falta una dependencia",
            "No se encontró mysql-connector-python.\nInstala las dependencias con:\n\n"
            "python -m pip install -r requirements.txt",
            parent=root,
        )
        root.destroy()
        return
    LoginWindow(root)
    root.mainloop()


if __name__ == "__main__":
    main()
