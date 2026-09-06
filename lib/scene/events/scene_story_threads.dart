part of '../../main.dart';

/// Kimlikler ve yıl kapıları saf StoryThreads'te; bu katman gerçek insanları,
/// evleri, sosyal niyetleri ve mevcut zanaat/hane sistemini birbirine bağlar.
extension _SceneStoryThreads on _VillageSceneState {
  bool _storyPersonPresent(VillagerEntity? v) =>
      v != null && !v.isDying && !v.isLeaving && _villagers.contains(v);

  bool _storyCastIntact(StoryCast<VillagerEntity>? cast) =>
      cast != null &&
      _storyPersonPresent(cast.lead) &&
      _storyPersonPresent(cast.partner);

  StoryCast<VillagerEntity>? _chooseStoryCast(StoryThread thread) {
    final people = _villagers
        .where((v) => _storyPersonPresent(v) && v.hasProfession)
        .toList();
    // Oyuncunun favorileri ve köyün ilk kuşağı önce gelir. Rastgele her
    // karşılaşmada yeni yüz üretmeyiz; yalnız açılışta kadro seçilir.
    people.sort((a, b) {
      int rank(VillagerEntity v) =>
          (v.isFavorite ? 2 : 0) + (v.parents.isEmpty ? 1 : 0);
      final order = rank(b).compareTo(rank(a));
      return order != 0
          ? order
          : _villagers.indexOf(a).compareTo(_villagers.indexOf(b));
    });
    for (final lead in people) {
      for (final partner in people) {
        if (identical(lead, partner)) continue;
        var craft = '';
        switch (thread) {
          case StoryThread.family:
            if (lead.homeBuilding is! BuildingEntity ||
                lead.surname.isEmpty ||
                partner.surname != lead.surname) {
              continue;
            }
          case StoryThread.apprenticeship:
            // Bu paket yapı ustalığını öğretir; meslekleri aniden değiştirmez.
            for (final c in Craft.structural) {
              if (_holdsCraft(lead, c) && !_holdsCraft(partner, c)) {
                craft = c;
                break;
              }
            }
            if (craft.isEmpty) continue;
          case StoryThread.accord:
            if (lead.surname.isEmpty ||
                partner.surname.isEmpty ||
                lead.surname == partner.surname) {
              continue;
            }
        }
        return StoryCast(
          lead: lead,
          partner: partner,
          leadName: lead.name,
          partnerName: partner.name,
          craft: craft,
        );
      }
    }
    return null;
  }

  ({Petition petition, VillagerEntity? author, Map<String, String> extra})?
  _prepareStoryPetition(Petition raw) {
    final thread = StoryThreads.threadOf(raw.id);
    if (thread == null ||
        _villageMemory.contains(StoryThreads.id(thread, 'done'))) {
      return null;
    }
    var cast = _storyCasts[thread];
    if (StoryThreads.isOpening(raw.id)) {
      if (_villageMemory.contains(StoryThreads.id(thread, 'started'))) {
        return null;
      }
      cast ??= _chooseStoryCast(thread);
      if (cast == null) return null; // kadro beklerken dağılmış olabilir
      _storyCasts[thread] = cast;
    }
    // Bozuk/eski bir kayıtta rolü olmayan hikâyeye rastgele geçmiş uydurma.
    if (cast == null) return null;
    final intact = _storyCastIntact(cast);
    final id = StoryThreads.chapterForCast(raw.id, intact: intact);
    if (intact && !StoryThreads.ready(id, _dayCount)) return null;
    final missing = [
      if (!_storyPersonPresent(cast.lead)) cast.leadName,
      if (!_storyPersonPresent(cast.partner)) cast.partnerName,
    ].join(' ve ');
    return (
      petition: PetitionSystem.requireById(id),
      author: _storyPersonPresent(cast.lead)
          ? cast.lead
          : _storyPersonPresent(cast.partner)
          ? cast.partner
          : null,
      extra: {
        'storyLead': _storyPersonPresent(cast.lead)
            ? cast.lead!.name
            : cast.leadName,
        'storyPartner': _storyPersonPresent(cast.partner)
            ? cast.partner!.name
            : cast.partnerName,
        'storyCraft': Craft.displayName(cast.craft),
        'storyMissing': missing,
      },
    );
  }

  /// Modal açıkken de dünya akar. Kayıp karar düğmesine basıldığı ana kadar
  /// olabilir; eski şıkkın kaynağını harcamadan kayıp sayfasına geçilir.
  bool _refreshLostStory(Petition p) {
    final thread = StoryThreads.threadOf(p.id);
    if (thread == null ||
        StoryThreads.isLoss(p.id) ||
        _storyCastIntact(_storyCasts[thread])) {
      return false;
    }
    _activatePetition(
      PetitionSystem.requireById(StoryThreads.id(thread, 'loss')),
    );
    setStateHere(() => _petitionModalOpen = true);
    return true;
  }

  void _applyStoryDecision(Petition p, PetitionOption option) {
    final thread = StoryThreads.threadOf(p.id);
    final cast = _storyCasts[thread];
    if (thread == null || cast == null) return;
    for (final person in [cast.lead, cast.partner]) {
      if (_storyPersonPresent(person)) {
        _lifeEvent(person!, option.resolution, icon: p.icon, milestone: true);
      }
    }
    if (StoryThreads.isLoss(p.id)) {
      _petitionFollowUps.removeWhere(
        (f) => StoryThreads.threadOf(f.id) == thread,
      );
      return;
    }
    final lead = cast.lead!;
    final partner = cast.partner!;
    if (_storyBondActive(thread)) {
      lead.grudges.remove(partner);
      partner.grudges.remove(lead);
      if (thread == StoryThread.family) _ensureStoryGarden(cast);
      lead.feel(NpcEmotion.content, 5.0, moodDelta: 0.04);
      partner.feel(NpcEmotion.content, 5.0, moodDelta: 0.04);
    }
    // Bir defalık son yıl desteği; hedefteki üç sadık haneyi bedavadan
    // tamamlamaz. Aile zincirinde aynı haneyi iki kez ödüllendirme.
    if (option.setsFlags.contains(StoryThreads.id(thread, 'backed'))) {
      for (final house in {lead.surname, partner.surname}) {
        if (house.isNotEmpty) {
          _houses.nudge(house, moodDelta: 0.12, swayGain: 0.04);
        }
      }
    }
  }

  bool _storyBondActive(StoryThread thread) => _villageMemory.contains(
    StoryThreads.id(thread, switch (thread) {
      StoryThread.family => 'garden',
      StoryThread.apprenticeship => 'teaching',
      StoryThread.accord => 'table',
    }),
  );

  void _ensureStoryGarden(StoryCast<VillagerEntity> cast) {
    const flag = 'story.family.planted';
    if (_villageMemory.contains(flag) || !_storyPersonPresent(cast.lead)) {
      return;
    }
    if (_plantPulseGarden(cast.lead!, 3) > 0) _villageMemory.add(flag);
  }

  bool _storyFree(VillagerEntity v) =>
      _storyPersonPresent(v) &&
      !v.isSleeping &&
      !v.isInsideBuilding &&
      !v.isCarrying &&
      !v.sitClaimed &&
      v.activity == VillagerActivity.none &&
      v.mind.intent.priority <= IntentPriority.routine &&
      v.socialCooldown <= 0;

  VillagerEntity? _storyPartner(VillagerEntity v) {
    for (final entry in _storyCasts.entries) {
      final cast = entry.value;
      if (!_storyBondActive(entry.key) ||
          !_storyCastIntact(cast) ||
          cast.lastMeetingDay >= _dayCount) {
        continue;
      }
      final other = identical(v, cast.lead)
          ? cast.partner
          : identical(v, cast.partner)
          ? cast.lead
          : null;
      if (other != null &&
          _storyFree(other) &&
          !v.memory.suspects(other) &&
          !other.memory.suspects(v) &&
          v.memory.opinionOf(other) >= -0.40 &&
          other.memory.opinionOf(v) >= -0.40) {
        return other;
      }
    }
    return null;
  }

  /// Zorunlu NPC emri değil, mevcut niyet hakemine rutin teklif. Açlık,
  /// uyku, tehlike ve oyuncunun işi daha yüksek öncelikte kalır.
  Bid? _bidStoryVisit(VillagerEntity v) {
    if (!_storyFree(v) ||
        _cycle.rainIntensity > 0.30 ||
        identical(v, _petitionAuthor)) {
      return null;
    }
    final other = _storyPartner(v);
    if (other == null || identical(other, _petitionAuthor)) return null;
    // Tek taraf yürür; çift birbirini kovalamasın. Diğeri yakında sohbet eder.
    final cast = _storyCasts.values
        .where((c) => identical(c.lead, v) && identical(c.partner, other))
        .firstOrNull;
    if (cast == null) return null;
    final distance = _wdist(v.gridX, v.gridY, other.gridX, other.gridY);
    if (distance <= 2.5 || distance > 18) return null;
    final spot = _freeSpotNear(other.gridX, other.gridY, 1.2);
    if (spot == null) return null;
    final label = Voice.say(const [
      '{öteki} ile eski söz için buluşuyor',
      '{öteki} ile ortak işini konuşmaya gidiyor',
      '{öteki} ile verdiği sözü sürdürüyor',
    ], _voice(v, other: other, seed: _dayCount));
    return Bid(
      kind: IntentKind.social,
      score: 1.0,
      reason: label,
      priority: IntentPriority.routine,
      begin: () {
        v.act = Act(label, [
          ActStep.goTo(spot.$1, spot.$2),
          ActStep.face(other.gridX, other.gridY),
          const ActStep.work(1.0, pose: ActPose.stand),
        ]);
      },
    );
  }

  /// Öğrenme ve bağ yalnız gerçek, yakın sosyal karşılaşmada ilerler.
  /// Bir güne bir ders: sim hızını artırmak veya yüklemek ustalık basmaz.
  void _onStoryConversation(VillagerEntity a, VillagerEntity b) {
    for (final entry in _storyCasts.entries) {
      final cast = entry.value;
      if (!_storyBondActive(entry.key) ||
          !_storyCastIntact(cast) ||
          cast.lastMeetingDay >= _dayCount) {
        continue;
      }
      if (!((identical(a, cast.lead) && identical(b, cast.partner)) ||
          (identical(b, cast.lead) && identical(a, cast.partner)))) {
        continue;
      }
      cast.lastMeetingDay = _dayCount;
      final label = Voice.say(switch (entry.key) {
        StoryThread.family => const [
          'birlikte bahçeye bakıyor',
          'kapı bahçesinde birlikte çalışıyor',
          'eski bahçe sözünü sürdürüyor',
        ],
        StoryThread.apprenticeship => const [
          'ustasıyla el alıştırıyor',
          'birlikte zanaat çalışıyor',
          'ustasının yanında öğreniyor',
        ],
        StoryThread.accord => const [
          'ortak sofrada konuşuyor',
          'eski uzlaşmayı aynı sofrada sürdürüyor',
          'komşu haneyle söz paylaşıyor',
        ],
      }, _voice(a, other: b, seed: _dayCount));
      final prop = switch (entry.key) {
        StoryThread.family => PropKind.bucketFull,
        StoryThread.apprenticeship => PropKind.firewood,
        StoryThread.accord => PropKind.bread,
      };
      final pose = entry.key == StoryThread.accord
          ? ActPose.sip
          : ActPose.labor;
      for (final person in [a, b]) {
        // Sosyal niyet zaten kazanmış; aynı karşılaşmanın görünür el işi.
        // Mevcut Act yürütücüsü uyku/ölümde eşyayı ve duruşu temizler.
        person.act = Act(label, [
          ActStep.take(prop),
          ActStep.work(5.0, pose: pose),
          const ActStep.put(),
        ]);
      }
      if (entry.key == StoryThread.apprenticeship &&
          _holdsCraft(cast.lead!, cast.craft)) {
        // Sekiz günlük gerçek buluşma yapı zanaatının taşıyıcı eşiğine
        // erişebilir. Ustanın bilgisi kadar öğrenilir; sonsuz XP kaynağı yok.
        final student = cast.partner!;
        final masterLevel = cast.lead!.mastery[cast.craft] ?? 0;
        final studentLevel = student.mastery[cast.craft] ?? 0;
        if (studentLevel < masterLevel) {
          student.gainMastery(cast.craft, min(1.0, masterLevel - studentLevel));
          cast.lessons++;
        }
      }
      if (entry.key == StoryThread.family) _ensureStoryGarden(cast);
      if (cast.lastMeetingDay > 0 &&
          !_villageMemory.contains(StoryThreads.id(entry.key, 'met'))) {
        _villageMemory.add(StoryThreads.id(entry.key, 'met'));
        final text = Voice.say(const [
          '{ad} ile {öteki}, verdiğin sözün ardından birlikte vakit ayırdı.',
          'Eski kararın sokakta karşılık buldu; {ad} ile {öteki} yeniden buluştu.',
          '{ad} ve {öteki}, divandaki sözü gündelik hayatlarına taşıdı.',
        ], _voice(a, other: b, seed: _dayCount));
        _lifeEvent(a, text, icon: '🤝', milestone: true);
        _lifeEvent(b, text, icon: '🤝', milestone: true);
        _chronicle(text, icon: '🤝', kind: ChronicleKind.life);
      }
    }
  }

  Map<String, String> _storyQuestNotes() {
    final notes = <String, String>{};
    for (final entry in _storyCasts.entries) {
      final thread = entry.key;
      if (!_villageMemory.contains(StoryThreads.id(thread, 'started'))) {
        continue;
      }
      final cast = entry.value;
      final intact = _storyCastIntact(cast);
      final backed = _villageMemory.contains(StoryThreads.id(thread, 'backed'));
      final local = _villageMemory.contains(StoryThreads.id(thread, 'local'));
      final pool = !intact
          ? const [
              '{storyLead} ve {storyPartner} için başlayan söz köyün geçmişinde duruyor.',
              'Bu hedefte {storyLead} ile {storyPartner} için verilmiş eski bir söz var.',
              'Köy, {storyLead} ve {storyPartner} ile başlayan meseleyi hatırlıyor.',
            ]
          : backed
          ? const [
              '{storyLead} ve {storyPartner} bu hedef için verdiğin desteği hatırlıyor.',
              'Bu hedef, {storyLead} ile {storyPartner} için desteklediğin ortaklığın devamı.',
              '{storyLead} ve {storyPartner} ile kurduğun ortaklığın köydeki karşılığı bu hedef.',
            ]
          : local
          ? const [
              '{storyLead} ve {storyPartner} ile meseleyi yerel tuttun; köyün hedefi sürüyor.',
              'Yerel bıraktığın {storyLead} ve {storyPartner} anlaşmasının ötesinde köyün işi var.',
              '{storyLead} ve {storyPartner} için büyük ortaklık kurmadın; bu hedef hâlâ açık.',
            ]
          : const [
              '{storyLead} ve {storyPartner} ile başlayan mesele, köy büyüdüğünde yeniden açılacak.',
              'Bu hedefin geçmişinde {storyLead} ve {storyPartner} için verdiğin söz var.',
              '{storyLead} ile {storyPartner} için açılan sayfa, büyüyen köyün bu işine uzanıyor.',
            ];
      notes[StoryThreads.questFor(thread)!] = Voice.say(
        pool,
        _voice(
          null,
          seed: _dayCount,
          extra: {
            'storyLead': _storyPersonPresent(cast.lead)
                ? cast.lead!.name
                : cast.leadName,
            'storyPartner': _storyPersonPresent(cast.partner)
                ? cast.partner!.name
                : cast.partnerName,
          },
        ),
      );
    }
    return notes;
  }
}
