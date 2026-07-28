(function () {
  "use strict";

  const quiz = window.BATTLE_BOG_QUIZ;
  const storageKey = "battle-bog-visual-reference-quiz-v1";

  const elements = {
    sectionNav: document.querySelector("#section-nav"),
    sectionNumber: document.querySelector("#section-number"),
    sectionTitle: document.querySelector("#section-title"),
    sectionDescription: document.querySelector("#section-description"),
    axisList: document.querySelector("#axis-list"),
    forcedPanel: document.querySelector("#forced-choice-panel"),
    referenceGrid: document.querySelector("#reference-grid"),
    referenceTemplate: document.querySelector("#reference-template"),
    emptyState: document.querySelector("#empty-state"),
    searchInput: document.querySelector("#search-input"),
    roleFilter: document.querySelector("#role-filter"),
    verdictFilter: document.querySelector("#verdict-filter"),
    previousSection: document.querySelector("#previous-section"),
    nextSection: document.querySelector("#next-section"),
    sectionCount: document.querySelector("#section-count"),
    progressLabel: document.querySelector("#progress-label"),
    progressFill: document.querySelector("#progress-fill"),
    progressTrack: document.querySelector(".progress-track"),
    saveState: document.querySelector("#save-state"),
    loveCount: document.querySelector("#love-count"),
    usefulCount: document.querySelector("#useful-count"),
    unsureCount: document.querySelector("#unsure-count"),
    rejectCount: document.querySelector("#reject-count"),
    anchorList: document.querySelector("#anchor-list"),
    specialistList: document.querySelector("#specialist-list"),
    boundaryList: document.querySelector("#boundary-list"),
    summaryButton: document.querySelector("#summary-button"),
    exportButton: document.querySelector("#export-button"),
    resetButton: document.querySelector("#reset-button"),
    summaryDialog: document.querySelector("#summary-dialog"),
    closeSummary: document.querySelector("#close-summary"),
    summaryContent: document.querySelector("#summary-content"),
    sessionName: document.querySelector("#session-name"),
    copyMarkdown: document.querySelector("#copy-markdown"),
    downloadMarkdown: document.querySelector("#download-markdown"),
    downloadJson: document.querySelector("#download-json")
  };

  const defaultState = {
    version: 1,
    activeSection: quiz.sections[0].id,
    responses: {},
    choices: {},
    sessionName: ""
  };

  let state = loadState();
  let saveTimer = null;

  initialize();

  function initialize() {
    elements.sessionName.value = state.sessionName || "";
    bindGlobalEvents();
    render();
  }

  function loadState() {
    try {
      const saved = JSON.parse(localStorage.getItem(storageKey));
      if (!saved || saved.version !== defaultState.version) {
        return structuredClone(defaultState);
      }
      return {
        ...structuredClone(defaultState),
        ...saved,
        responses: saved.responses || {},
        choices: saved.choices || {}
      };
    } catch (_error) {
      return structuredClone(defaultState);
    }
  }

  function bindGlobalEvents() {
    elements.searchInput.addEventListener("input", renderCards);
    elements.roleFilter.addEventListener("change", renderCards);
    elements.verdictFilter.addEventListener("change", renderCards);

    elements.previousSection.addEventListener("click", () => moveSection(-1));
    elements.nextSection.addEventListener("click", () => moveSection(1));

    elements.summaryButton.addEventListener("click", openSummary);
    elements.exportButton.addEventListener("click", openSummary);
    elements.closeSummary.addEventListener("click", () =>
      elements.summaryDialog.close()
    );

    elements.summaryDialog.addEventListener("click", (event) => {
      if (event.target === elements.summaryDialog) {
        elements.summaryDialog.close();
      }
    });

    elements.sessionName.addEventListener("input", () => {
      state.sessionName = elements.sessionName.value.trim();
      scheduleSave();
    });

    elements.copyMarkdown.addEventListener("click", async () => {
      const copied = await copyText(buildMarkdownExport());
      flashButton(elements.copyMarkdown, copied ? "Copied" : "Copy failed");
    });

    elements.downloadMarkdown.addEventListener("click", () => {
      downloadFile(
        `${exportBaseName()}.md`,
        buildMarkdownExport(),
        "text/markdown;charset=utf-8"
      );
    });

    elements.downloadJson.addEventListener("click", () => {
      downloadFile(
        `${exportBaseName()}.json`,
        JSON.stringify(buildJsonExport(), null, 2),
        "application/json;charset=utf-8"
      );
    });

    elements.resetButton.addEventListener("click", () => {
      const confirmed = window.confirm(
        "Reset every verdict, note and calibration answer in this quiz?"
      );
      if (!confirmed) {
        return;
      }

      state = structuredClone(defaultState);
      elements.searchInput.value = "";
      elements.roleFilter.value = "all";
      elements.verdictFilter.value = "all";
      elements.sessionName.value = "";
      saveImmediately();
      render();
    });
  }

  function render() {
    const activeSection = getActiveSection();
    if (!activeSection) {
      state.activeSection = quiz.sections[0].id;
    }

    renderNavigation();
    renderSectionHeader();
    renderForcedChoices();
    renderCards();
    renderProgress();
    renderDecisionTray();
    renderPager();
  }

  function getActiveSection() {
    return quiz.sections.find((section) => section.id === state.activeSection);
  }

  function renderNavigation() {
    elements.sectionNav.replaceChildren();

    quiz.sections.forEach((section) => {
      const items = quiz.items.filter((item) => item.section === section.id);
      const rated = items.filter(
        (item) => state.responses[item.id] && state.responses[item.id].verdict
      ).length;

      const button = document.createElement("button");
      button.type = "button";
      button.className = "section-nav-button";
      button.classList.toggle("is-active", section.id === state.activeSection);
      button.setAttribute(
        "aria-current",
        section.id === state.activeSection ? "page" : "false"
      );
      button.innerHTML = `
        <span class="section-nav-number">${section.number}</span>
        <span class="section-nav-title">${escapeHtml(section.short)}</span>
        <span class="section-nav-progress">${rated}/${items.length}</span>
      `;
      button.addEventListener("click", () => setSection(section.id));
      elements.sectionNav.append(button);
    });
  }

  function renderSectionHeader() {
    const section = getActiveSection();
    elements.sectionNumber.textContent = `Section ${section.number}`;
    elements.sectionTitle.textContent = section.title;
    elements.sectionDescription.textContent = section.description;
    elements.axisList.replaceChildren(
      ...section.axes.map((axis) => {
        const chip = document.createElement("span");
        chip.textContent = axis;
        return chip;
      })
    );
  }

  function renderForcedChoices() {
    const choices = quiz.forcedChoices.filter(
      (choice) => choice.section === state.activeSection
    );
    elements.forcedPanel.replaceChildren();
    elements.forcedPanel.hidden = choices.length === 0;

    choices.forEach((choice, index) => {
      const copy = document.createElement("div");
      copy.className = "forced-copy";
      copy.innerHTML = `
        <span class="eyebrow">Fast calibration ${choices.length > 1 ? index + 1 : ""}</span>
        <h2>${escapeHtml(choice.prompt)}</h2>
      `;

      const options = document.createElement("div");
      options.className = "segmented";
      options.setAttribute("role", "group");
      options.setAttribute("aria-label", choice.prompt);

      choice.options.forEach((option) => {
        const button = document.createElement("button");
        button.type = "button";
        button.textContent = option;
        button.classList.toggle("is-selected", state.choices[choice.id] === option);
        button.addEventListener("click", () => {
          state.choices[choice.id] =
            state.choices[choice.id] === option ? "" : option;
          scheduleSave();
          renderForcedChoices();
          renderProgress();
        });
        options.append(button);
      });

      elements.forcedPanel.append(copy, options);
    });
  }

  function renderCards() {
    const search = elements.searchInput.value.trim().toLowerCase();
    const roleFilter = elements.roleFilter.value;
    const verdictFilter = elements.verdictFilter.value;

    const items = quiz.items.filter((item) => {
      if (item.section !== state.activeSection) {
        return false;
      }

      const response = state.responses[item.id] || {};
      const searchable = [
        item.game,
        item.title,
        item.role,
        item.focus,
        item.context,
        item.question
      ]
        .join(" ")
        .toLowerCase();

      const matchesSearch = !search || searchable.includes(search);
      const matchesRole = roleFilter === "all" || item.role === roleFilter;
      const matchesVerdict =
        verdictFilter === "all" ||
        (verdictFilter === "unrated"
          ? !response.verdict
          : response.verdict === verdictFilter);

      return matchesSearch && matchesRole && matchesVerdict;
    });

    elements.referenceGrid.replaceChildren(
      ...items.map((item) => buildCard(item))
    );
    elements.emptyState.hidden = items.length > 0;
  }

  function buildCard(item) {
    const response = state.responses[item.id] || {
      verdict: "",
      scopes: [],
      notes: ""
    };
    const card = elements.referenceTemplate.content.firstElementChild.cloneNode(true);

    card.dataset.itemId = item.id;
    card.dataset.role = item.role;
    card.dataset.verdict = response.verdict || "";

    const imageLink = card.querySelector(".reference-image-link");
    imageLink.href = item.sourceUrl;
    imageLink.setAttribute(
      "aria-label",
      `Open source for ${item.game}: ${item.title}`
    );

    const image = card.querySelector(".reference-image");
    image.src = item.image;
    image.alt = `${item.game} reference: ${item.title}`;
    image.addEventListener("error", () => {
      image.alt = `${item.game} image unavailable. Open the source link.`;
      image.classList.add("is-missing");
    });

    card.querySelector(".source-badge").textContent = item.sourceType;
    card.querySelector(".source-badge").title = item.sourceType;
    card.querySelector(".role-badge").textContent = item.role;
    card.querySelector(".game-name").textContent = item.game;
    card.querySelector(".reference-title").textContent = item.title;
    card.querySelector(".focus-copy").textContent = item.focus;
    card.querySelector(".context-copy").textContent = item.context;
    card.querySelector(".question-copy").textContent = item.question;
    card.querySelector(".limits-copy").textContent = `Cannot establish: ${item.limits}`;

    const contextLink = card.querySelector(".context-link");
    contextLink.href = item.contextUrl || item.sourceUrl;
    contextLink.textContent =
      item.contextUrl && item.contextUrl.includes("youtube") ? "Footage" : "Context";

    card.querySelectorAll("[data-verdict]").forEach((button) => {
      const verdict = button.dataset.verdict;
      button.classList.toggle("is-selected", response.verdict === verdict);
      button.setAttribute("aria-pressed", response.verdict === verdict);
      button.addEventListener("click", () => {
        const current = state.responses[item.id] || {
          verdict: "",
          scopes: [],
          notes: ""
        };
        current.verdict = current.verdict === verdict ? "" : verdict;
        state.responses[item.id] = current;
        scheduleSave();
        renderCards();
        renderNavigation();
        renderProgress();
        renderDecisionTray();
      });
    });

    card.querySelectorAll('.scope-fieldset input[type="checkbox"]').forEach(
      (checkbox) => {
        checkbox.checked = (response.scopes || []).includes(checkbox.value);
        checkbox.addEventListener("change", () => {
          const current = state.responses[item.id] || {
            verdict: "",
            scopes: [],
            notes: ""
          };
          const scopes = new Set(current.scopes || []);
          if (checkbox.checked) {
            scopes.add(checkbox.value);
          } else {
            scopes.delete(checkbox.value);
          }
          current.scopes = [...scopes];
          state.responses[item.id] = current;
          scheduleSave();
          renderDecisionTray();
        });
      }
    );

    const notes = card.querySelector("textarea");
    notes.value = response.notes || "";
    notes.addEventListener("input", () => {
      const current = state.responses[item.id] || {
        verdict: "",
        scopes: [],
        notes: ""
      };
      current.notes = notes.value;
      state.responses[item.id] = current;
      scheduleSave();
    });

    if ((response.scopes && response.scopes.length) || response.notes) {
      card.querySelector("details").open = true;
    }

    return card;
  }

  function renderProgress() {
    const rated = quiz.items.filter(
      (item) => state.responses[item.id] && state.responses[item.id].verdict
    ).length;
    const answeredChoices = quiz.forcedChoices.filter(
      (choice) => state.choices[choice.id]
    ).length;
    const totalSteps = quiz.items.length + quiz.forcedChoices.length;
    const completedSteps = rated + answeredChoices;
    const percent = totalSteps ? Math.round((completedSteps / totalSteps) * 100) : 0;

    elements.progressLabel.textContent =
      `${rated} of ${quiz.items.length} references rated` +
      ` · ${answeredChoices} of ${quiz.forcedChoices.length} calibrations`;
    elements.progressFill.style.width = `${percent}%`;
    elements.progressTrack.setAttribute("aria-valuenow", String(percent));
  }

  function renderDecisionTray() {
    const counts = { love: 0, useful: 0, unsure: 0, reject: 0 };
    Object.values(state.responses).forEach((response) => {
      if (response.verdict && counts[response.verdict] !== undefined) {
        counts[response.verdict] += 1;
      }
    });

    elements.loveCount.textContent = counts.love;
    elements.usefulCount.textContent = counts.useful;
    elements.unsureCount.textContent = counts.unsure;
    elements.rejectCount.textContent = counts.reject;

    renderTrayList(
      elements.anchorList,
      uniqueGamesForVerdict("love"),
      "No visible anchors chosen yet."
    );
    renderTrayList(
      elements.specialistList,
      uniqueGamesForVerdict("useful"),
      "No specialist references chosen yet."
    );
    renderTrayList(
      elements.boundaryList,
      uniqueGamesForVerdict("reject"),
      "No explicit boundaries chosen yet."
    );
  }

  function uniqueGamesForVerdict(verdict) {
    const gameMap = new Map();

    quiz.items.forEach((item) => {
      const response = state.responses[item.id];
      if (!response || response.verdict !== verdict) {
        return;
      }
      const existing = gameMap.get(item.game) || {
        game: item.game,
        scopes: new Set(),
        count: 0
      };
      (response.scopes || []).forEach((scope) => existing.scopes.add(scope));
      existing.count += 1;
      gameMap.set(item.game, existing);
    });

    return [...gameMap.values()]
      .sort((a, b) => b.count - a.count || a.game.localeCompare(b.game))
      .slice(0, 6);
  }

  function renderTrayList(target, entries, emptyMessage) {
    target.replaceChildren();
    if (!entries.length) {
      const empty = document.createElement("li");
      empty.textContent = emptyMessage;
      target.append(empty);
      return;
    }

    entries.forEach((entry) => {
      const item = document.createElement("li");
      const scopes = [...entry.scopes];
      item.innerHTML = `<strong>${escapeHtml(entry.game)}</strong>${
        scopes.length ? ` · ${escapeHtml(scopes.join(", "))}` : ""
      }`;
      target.append(item);
    });
  }

  function renderPager() {
    const index = quiz.sections.findIndex(
      (section) => section.id === state.activeSection
    );
    elements.previousSection.disabled = index <= 0;
    elements.nextSection.disabled = index >= quiz.sections.length - 1;
    elements.nextSection.textContent =
      index >= quiz.sections.length - 1 ? "Final section" : "Next section";
    elements.sectionCount.textContent =
      `${index + 1} of ${quiz.sections.length} sections`;
  }

  function moveSection(direction) {
    const index = quiz.sections.findIndex(
      (section) => section.id === state.activeSection
    );
    const nextIndex = Math.max(
      0,
      Math.min(quiz.sections.length - 1, index + direction)
    );
    if (nextIndex !== index) {
      setSection(quiz.sections[nextIndex].id);
    }
  }

  function setSection(sectionId) {
    state.activeSection = sectionId;
    elements.searchInput.value = "";
    elements.roleFilter.value = "all";
    elements.verdictFilter.value = "all";
    scheduleSave();
    render();
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function scheduleSave() {
    window.clearTimeout(saveTimer);
    elements.saveState.textContent = "Saving...";
    saveTimer = window.setTimeout(saveImmediately, 220);
  }

  function saveImmediately() {
    localStorage.setItem(storageKey, JSON.stringify(state));
    elements.saveState.textContent = `Saved ${new Date().toLocaleTimeString([], {
      hour: "numeric",
      minute: "2-digit"
    })}`;
  }

  function openSummary() {
    renderSummary();
    if (typeof elements.summaryDialog.showModal === "function") {
      elements.summaryDialog.showModal();
    }
  }

  function renderSummary() {
    const groups = {
      love: itemsWithVerdict("love"),
      useful: itemsWithVerdict("useful"),
      unsure: itemsWithVerdict("unsure"),
      reject: itemsWithVerdict("reject")
    };

    const choices = quiz.forcedChoices
      .filter((choice) => state.choices[choice.id])
      .map(
        (choice) =>
          `<li><strong>${escapeHtml(choice.prompt)}</strong><br>${escapeHtml(
            state.choices[choice.id]
          )}</li>`
      )
      .join("");

    elements.summaryContent.innerHTML = `
      <h3>Calibration decisions</h3>
      ${
        choices
          ? `<ul>${choices}</ul>`
          : "<p>No fast-calibration decisions have been made yet.</p>"
      }
      ${summaryGroupHtml("Visible anchors", groups.love)}
      ${summaryGroupHtml("Useful specialist references", groups.useful)}
      ${summaryGroupHtml("Still unresolved", groups.unsure)}
      ${summaryGroupHtml("Explicit visual boundaries", groups.reject)}
    `;
  }

  function summaryGroupHtml(title, entries) {
    if (!entries.length) {
      return `<h3>${escapeHtml(title)}</h3><p>None selected.</p>`;
    }

    const list = entries
      .map(({ item, response }) => {
        const scopes = response.scopes && response.scopes.length
          ? ` · Mine for: ${response.scopes.join(", ")}`
          : "";
        const notes = response.notes
          ? `<br><em>${escapeHtml(response.notes)}</em>`
          : "";
        return `<li><strong>${escapeHtml(item.game)} — ${escapeHtml(
          item.title
        )}</strong>${escapeHtml(scopes)}${notes}</li>`;
      })
      .join("");

    return `<h3>${escapeHtml(title)}</h3><ul>${list}</ul>`;
  }

  function itemsWithVerdict(verdict) {
    return quiz.items
      .filter((item) => state.responses[item.id]?.verdict === verdict)
      .map((item) => ({ item, response: state.responses[item.id] }));
  }

  function buildJsonExport() {
    return {
      schema: "battle-bog-visual-reference-quiz-v1",
      sessionName: state.sessionName || "Battle Bog visual preference pass",
      exportedAt: new Date().toISOString(),
      calibration: quiz.forcedChoices.map((choice) => ({
        id: choice.id,
        prompt: choice.prompt,
        answer: state.choices[choice.id] || null
      })),
      references: quiz.items.map((item) => {
        const response = state.responses[item.id] || {};
        return {
          id: item.id,
          section: item.section,
          game: item.game,
          title: item.title,
          role: item.role,
          verdict: response.verdict || null,
          mineFor: response.scopes || [],
          notes: response.notes || "",
          question: item.question,
          sourceUrl: item.sourceUrl,
          contextUrl: item.contextUrl,
          sourceType: item.sourceType,
          limitation: item.limits
        };
      })
    };
  }

  function buildMarkdownExport() {
    const title = state.sessionName || "Battle Bog Visual Preference Results";
    const lines = [
      `# ${title}`,
      "",
      `Exported: ${new Date().toISOString()}`,
      "",
      "## Calibration",
      ""
    ];

    quiz.forcedChoices.forEach((choice) => {
      lines.push(
        `- **${choice.prompt}** ${state.choices[choice.id] || "_Unanswered_"}`
      );
    });

    [
      ["love", "Visible Style Anchors"],
      ["useful", "Useful Specialist References"],
      ["unsure", "Unresolved References"],
      ["reject", "Explicit Visual Boundaries"]
    ].forEach(([verdict, heading]) => {
      lines.push("", `## ${heading}`, "");
      const entries = itemsWithVerdict(verdict);
      if (!entries.length) {
        lines.push("_None selected._");
        return;
      }

      entries.forEach(({ item, response }) => {
        lines.push(`### ${item.game}: ${item.title}`, "");
        lines.push(`- Role: ${item.role}`);
        lines.push(
          `- Mine for: ${
            response.scopes && response.scopes.length
              ? response.scopes.join(", ")
              : "Not specified"
          }`
        );
        lines.push(`- Tested question: ${item.question}`);
        lines.push(`- Source: [${item.sourceType}](${item.sourceUrl})`);
        if (item.contextUrl && item.contextUrl !== item.sourceUrl) {
          lines.push(`- Supporting context: ${item.contextUrl}`);
        }
        lines.push(`- Source limitation: ${item.limits}`);
        if (response.notes) {
          lines.push(`- Notes: ${response.notes.replace(/\r?\n/g, " ")}`);
        }
        lines.push("");
      });
    });

    lines.push(
      "## Interpretation Guardrail",
      "",
      "A `Useful` verdict approves only the named technique or selected mining scopes. It does not approve the source game's complete visual style.",
      "",
      "Reference images and footage remain research evidence. No source assets are authorized for reuse in Battle Bog."
    );

    return lines.join("\n");
  }

  function exportBaseName() {
    return (state.sessionName || "battle-bog-visual-preferences")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "");
  }

  function downloadFile(filename, content, type) {
    const blob = new Blob([content], { type });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.append(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  }

  async function copyText(text) {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
        return true;
      }

      const textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.append(textarea);
      textarea.select();
      const copied = document.execCommand("copy");
      textarea.remove();
      return copied;
    } catch (_error) {
      return false;
    }
  }

  function flashButton(button, label) {
    const original = button.textContent;
    button.textContent = label;
    window.setTimeout(() => {
      button.textContent = original;
    }, 1200);
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }
})();
