const STORAGE_KEY = "mini-todo-items-v1";
const STORAGE_ERROR_MESSAGE =
  "브라우저 저장소에 접근할 수 없어 변경 사항이 새로고침 뒤 유지되지 않을 수 있어요.";

const state = {
  todos: loadTodos(),
  deferredInstallPrompt: null,
};

const elements = {
  form: document.querySelector("#todoForm"),
  input: document.querySelector("#todoInput"),
  list: document.querySelector("#todoList"),
  emptyState: document.querySelector("#emptyState"),
  formMessage: document.querySelector("#formMessage"),
  remainingCount: document.querySelector("#remainingCount"),
  completedCount: document.querySelector("#completedCount"),
  focusMessage: document.querySelector("#focusMessage"),
  todayLabel: document.querySelector("#todayLabel"),
  installButton: document.querySelector("#installButton"),
  installNote: document.querySelector("#installNote"),
};

initialize();

function initialize() {
  renderDate();
  render();
  setupInstallPrompt();
  registerServiceWorker();

  elements.form.addEventListener("submit", (event) => {
    event.preventDefault();

    const value = elements.input.value.trim();

    if (!value) {
      setMessage("할 일을 입력한 뒤 추가해 주세요.");
      elements.input.focus();
      return;
    }

    state.todos.unshift({
      id: crypto.randomUUID(),
      text: value,
      completed: false,
    });

    elements.form.reset();
    setMessage("할 일이 추가됐어요.");
    persistTodos();
    render();
    elements.input.focus();
  });
}

function setupInstallPrompt() {
  elements.installButton.addEventListener("click", installApp);

  if (isStandaloneMode()) {
    setInstallNote("이미 앱처럼 실행 중이에요.");
    return;
  }

  if (window.location.protocol === "file:") {
    setInstallNote("설치 기능은 로컬 서버나 배포된 주소에서 사용할 수 있어요.");
    return;
  }

  if (isIos()) {
    setInstallNote("iPhone/iPad에서는 공유 버튼을 눌러 ‘홈 화면에 추가’로 설치할 수 있어요.");
    return;
  }

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    state.deferredInstallPrompt = event;
    elements.installButton.hidden = false;
    setInstallNote("브라우저에 설치해서 앱처럼 바로 실행할 수 있어요.");
  });

  window.addEventListener("appinstalled", () => {
    ㅔ
    state.deferredInstallPrompt = null;
    elements.installButton.hidden = true;
    setInstallNote("앱 설치가 완료됐어요.");
  });
}

function renderDate() {
  const formatter = new Intl.DateTimeFormat("ko-KR", {
    month: "long",
    day: "numeric",
    weekday: "long",
  });

  elements.todayLabel.textContent = formatter.format(new Date());
}

function render() {
  elements.list.innerHTML = "";

  state.todos.forEach((todo) => {
    const item = document.createElement("li");
    item.className = `todo-item${todo.completed ? " completed" : ""}`;

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.className = "check-button";
    checkbox.checked = todo.completed;
    checkbox.setAttribute("aria-label", `${todo.text} 완료 여부`);
    checkbox.addEventListener("change", () => toggleTodo(todo.id));

    const text = document.createElement("span");
    text.className = "todo-text";
    text.textContent = todo.text;

    item.append(checkbox, text);
    elements.list.append(item);
  });

  const completedCount = state.todos.filter((todo) => todo.completed).length;
  const remainingCount = state.todos.length - completedCount;

  elements.remainingCount.textContent = String(remainingCount);
  elements.completedCount.textContent = String(completedCount);
  elements.emptyState.hidden = state.todos.length > 0;
  elements.focusMessage.textContent =
    remainingCount === 0 && state.todos.length > 0
      ? "오늘 할 일을 모두 마쳤어요. 멋져요!"
      : remainingCount > 0
        ? `지금 ${remainingCount}개 남았어요. 하나씩 끝내봐요.`
        : "가볍게 하나부터 시작해요.";
}

function toggleTodo(id) {
  state.todos = state.todos.map((todo) =>
    todo.id === id ? { ...todo, completed: !todo.completed } : todo,
  );

  persistTodos();
  render();
}

function setMessage(message) {
  elements.formMessage.textContent = message;
}

function persistTodos() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state.todos));
  } catch (error) {
    console.error("Failed to persist todos to storage", error);
    setMessage(STORAGE_ERROR_MESSAGE);
  }
}

async function installApp() {
  if (!state.deferredInstallPrompt) {
    setInstallNote("브라우저 메뉴의 ‘설치’ 또는 ‘홈 화면에 추가’를 사용해 주세요.");
    return;
  }

  state.deferredInstallPrompt.prompt();
  const { outcome } = await state.deferredInstallPrompt.userChoice;

  if (outcome === "accepted") {
    setInstallNote("설치를 진행하고 있어요.");
  } else {
    setInstallNote("설치를 취소했어요. 필요할 때 다시 설치할 수 있어요.");
  }

  state.deferredInstallPrompt = null;
  elements.installButton.hidden = true;
}

function registerServiceWorker() {
  if (!("serviceWorker" in navigator) || window.location.protocol === "file:") {
    return;
  }

  window.addEventListener("load", async () => {
    try {
      await navigator.serviceWorker.register("./sw.js");
    } catch (error) {
      console.error("Failed to register service worker", error);
    }
  });
}

function setInstallNote(message) {
  elements.installNote.textContent = message;
}

function isStandaloneMode() {
  return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone;
}

function isIos() {
  return /iphone|ipad|ipod/i.test(window.navigator.userAgent);
}

function loadTodos() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    const parsed = raw ? JSON.parse(raw) : [];

    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed
      .filter((todo) => typeof todo?.text === "string" && typeof todo?.completed === "boolean")
      .map((todo) => ({
        id: typeof todo.id === "string" ? todo.id : crypto.randomUUID(),
        text: todo.text.trim(),
        completed: todo.completed,
      }))
      .filter((todo) => todo.text.length > 0);
  } catch (error) {
    console.error("Failed to load todos from storage", error);
    return [];
  }
}
